#!/bin/bash
script_path="${BASH_SOURCE[0]}"
if [[ -L "$script_path" ]]; then
    script_path="$(readlink "$script_path")"
fi
if [[ "$script_path" != /* ]]; then
    script_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "$script_path")"
fi
script_dir="$(cd "$(dirname "$script_path")" && pwd)"
# shellcheck source=graphql-queries.sh
source "${script_dir}/graphql-queries.sh"

curlBin=$(which curl)
# use snap curl version if your OS is outdated
#curlBin=/snap/bin/curl
token_file=''
automatic_download=0
batch_mode=0
links_file=''
DOWNLOAD_FAIL_REASON=''
skip_existing_files=1

log_msg() {
    echo "$1"
    if [[ $batch_mode -eq 1 ]]; then
        echo "$1" >> "$LOG_FILE"
    fi
}

graphql_response_ok() {
    local outfile="$1"
    local error_msg
    [[ -f "$outfile" ]] || return 1
    error_msg=$(jq -r '.errors[0].message // empty' "$outfile" 2>/dev/null)
    [[ -n "$error_msg" ]] && return 1
    jq -e '.data | values | length > 0' "$outfile" >/dev/null 2>&1
}

fetch_graphql() {
    local operation_name="$1"
    local query="$2"
    local variables_json="$3"
    local outfile="$4"
    local max_retries=5
    local attempt=1
    local status error_msg payload

    payload=$(jq -nc \
        --arg query "$query" \
        --argjson variables "$variables_json" \
        --arg operationName "$operation_name" \
        '{query: $query, variables: $variables, operationName: $operationName}')

    while [[ $attempt -le $max_retries ]]; do
        status=$("$curlBin" -s -o "$outfile" -w "%{http_code}" \
            -X POST 'https://data.ardplus.de/ard/graphql' \
            -H 'authority: data.ardplus.de' \
            -H 'content-type: application/json' \
            -H "cookie: sid=$token" \
            -H 'origin: https://www.ardplus.de' \
            -H 'referer: https://www.ardplus.de/' \
            -H 'user-agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36' \
            --data-raw "$payload")

        if [[ "$status" == "200" ]] && graphql_response_ok "$outfile"; then
            echo "$status"
            return 0
        fi

        error_msg=$(jq -r '.errors[0].message // empty' "$outfile" 2>/dev/null)
        log_msg "GraphQL request failed (attempt ${attempt}/${max_retries}, HTTP ${status}, error: ${error_msg:-empty data}), retrying..." >&2

        if [[ $attempt -lt $max_retries ]]; then
            sleep $((attempt))
        fi
        attempt=$((attempt + 1))
    done

    return 1
}

resolve_download_path() {
    echo "${downloads_dir}/${1}"
}

output_mp4_path() {
    echo "$(resolve_download_path "$1").mp4"
}

has_incomplete_artifacts() {
    local filename="$1"
    local output_path dir base
    output_path=$(output_mp4_path "$filename")
    dir=$(dirname "$output_path")
    base=$(basename "$output_path" .mp4)

    compgen -G "${dir}/${base}"*.part* > /dev/null && return 0
    compgen -G "${dir}/${base}"*.ytdl > /dev/null && return 0
    [[ -f "${output_path}.ytdl" ]] && return 0
    return 1
}

cleanup_incomplete_files() {
    local filename="$1"
    local output_path dir base f
    output_path=$(output_mp4_path "$filename")
    dir=$(dirname "$output_path")
    base=$(basename "$output_path" .mp4)

    shopt -s nullglob
    for f in "${dir}/${base}"*.part* "${dir}/${base}"*.ytdl "${output_path}.ytdl"; do
        log_msg "Removing incomplete file: ${f}"
        rm -f -- "$f"
    done
    shopt -u nullglob
}

is_complete_file() {
    local filename="$1"
    local output_path
    output_path=$(output_mp4_path "$filename")

    [[ -f "$output_path" && -s "$output_path" ]] || return 1
    has_incomplete_artifacts "$filename" && return 1
    return 0
}

skip_if_exists() {
    local filename="$1"
    local output_path
    output_path=$(output_mp4_path "$filename")

    if [[ $skip_existing_files -eq 1 ]]; then
        if [[ -f "$output_path" && -s "$output_path" ]] && has_incomplete_artifacts "$filename"; then
            cleanup_incomplete_files "$filename"
            log_msg "SKIP (already exists): ${output_path}"
            return 0
        fi
        if is_complete_file "$filename"; then
            log_msg "SKIP (already exists): ${output_path}"
            return 0
        fi
    fi

    cleanup_incomplete_files "$filename"
    if [[ -f "$output_path" ]]; then
        log_msg "Incomplete file, re-downloading: ${output_path}"
    fi
    return 1
}

normalize_url() {
    local url="$1"
    url="${url%%#*}"
    url="${url%"${url##*[![:space:]]}"}"
    url="${url#"${url%%[![:space:]]*}"}"
    url="${url%/}"
    echo "$url"
}

sanitize_path_component() {
    local s="${1//\// }"
    printf '%s' "$s"
}

resolve_token_file() {
    local state_dir="${XDG_STATE_HOME:-${HOME:-}/.local/state}/ard-plus-dl"
    if [[ -n "${HOME:-}" ]] && mkdir -p "$state_dir" 2>/dev/null; then
        token_file="${state_dir}/token"
    else
        token_file="${work_dir}/.ard-plus-dl/token"
        mkdir -p "$(dirname "$token_file")"
    fi
}

decode_jwt_header() {
    local jwt="$1" header padded mod
    header="${jwt%%.*}"
    [[ -z "$header" ]] && return 1
    padded=$(printf '%s' "$header" | tr '_-' '/+')
    mod=$((${#padded} % 4))
    if [[ $mod -eq 2 ]]; then
        padded="${padded}=="
    elif [[ $mod -eq 3 ]]; then
        padded="${padded}="
    fi
    printf '%s' "$padded" | base64 -d 2>/dev/null | jq -r '.typ // empty'
}

write_token_file() {
    local saved_umask
    saved_umask=$(umask)
    umask 077
    mkdir -p "$(dirname "$token_file")"
    printf '%s\n' "$token" >"$token_file"
    umask "$saved_umask"
}

record_success() {
    echo "$1" >> "$SUCCESS_FILE"
    log_msg "Recorded success: $1"
}

record_failure() {
    local url="$1"
    local reason="$2"
    reason="${reason//$'\t'/ }"
    reason="${reason//$'\n'/ }"
    printf '%s\t%s\n' "$url" "$reason" >> "$FAILED_FILE"
    log_msg "Recorded failure: $url ($reason)"
}

run_yt_dlp() {
    local downloadUrl="$1"
    local filename="$2"
    local label="$3"
    local output_path
    output_path=$(resolve_download_path "$filename")
    if ! yt-dlp --quiet --progress --no-warnings --audio-multistreams \
        -f "bv+mergeall[vcodec=none]" --sub-langs "en.*,de.*" --embed-subs \
        --merge-output-format mp4 "${downloadUrl}" -o "$output_path"; then
        DOWNLOAD_FAIL_REASON="yt-dlp download failed for ${label}"
        return 1
    fi
    return 0
}

# login only if necessary
login() {
    encoded_username=$(printf %s "$username" | jq -s -R -r @uri)
    encoded_password=$(printf %s "$password" | jq -s -R -r @uri)
    token=$("$curlBin" -is 'https://auth.ardplus.de/auth/login?plainRedirect=true&redirectURL=https%3A%2F%2Fwww.ardplus.de%2Flogin%2Fcallback&errorRedirectURL=https%3A%2F%2Fwww.ardplus.de%2Fanmeldung%3Ferror%3Dtrue' \
    -H 'authority: auth.ardplus.de' \
    -H 'content-type: application/x-www-form-urlencoded' \
    -H 'origin: https://www.ardplus.de' \
    -H 'referer: https://www.ardplus.de/' \
    -H 'user-agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36' \
    --data-raw "username=${encoded_username}&password=${encoded_password}" | grep -i '^authorization:' | head -n 1 | awk '{print $3}' | tr -d '\r')
    token=$(printf '%s' "$token" | tr -d '\r')
    tokenType=$(decode_jwt_header "$token")
    if [[ "$tokenType" == "JWT" ]]; then
        write_token_file
    else
        echo "Login not possible! Please check credentials and subscription for user $username."
        exit 1
    fi
}

# cleanup after each episode and at the end
cleanup() {
    deleteToken=$("$curlBin" -s 'https://token.ardplus.de/token/session/playback/delete' \
    -H 'authority: token.ardplus.de' \
    -H 'content-type: application/json' \
    -H "cookie: sid=$token" \
    -H 'origin: https://www.ardplus.de' \
    -H 'referer: https://www.ardplus.de/' \
    -H 'user-agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36' \
    --data-raw "{\"contentId\":\"$movieId\",\"contentType\":\"CmsMovie\"}" \
    --compressed)
}

# get authorization for content
auth() {
    auth=$("$curlBin" -s 'https://token.ardplus.de/token/session' \
        -H 'authority: token.ardplus.de' \
        -H 'content-type: application/json' \
        -H "cookie: sid=$token" \
        -H 'origin: https://www.ardplus.de' \
        -H 'referer: https://www.ardplus.de/' \
        -H 'user-agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36' \
        --data-raw "{\"contentId\":\"$movieId\",\"contentType\":\"CmsEpisode\",\"download\":false,\"appInfo\":{\"platform\":\"web\",\"appVersion\":\"1.0.0\",\"build\":\"web\",\"bundleIdentifier\":\"web\"},\"deviceInfo\":{\"isTouchDevice\":false,\"isTablet\":false,\"isFireOS\":false,\"appPlatform\":\"web\",\"isIOS\":false,\"isCastReceiver\":false,\"isSafari\":false,\"isFirefox\":false}}" \
        --compressed)
    urlParam=$(echo ${auth} | jq -r '.authorizationParams')
    echo "$urlParam"
}

ensure_token() {
    if [[ -f "$token_file" ]]; then
        token=$(<"$token_file")
        token=$(printf '%s' "$token" | tr -d '\r\n')
    else
        login
        token=$(<"$token_file")
        token=$(printf '%s' "$token" | tr -d '\r\n')
    fi

    movieId="a0S010000007GcX"
    urlParam=$(auth)
    if [[ "$urlParam" == null || -z "$urlParam" ]]; then
        rm -f "$token_file"
        login
        if [[ ! -f "$token_file" ]]; then
            echo "Login not possible! Please check credentials and subscription for user $username."
            exit 1
        fi
        token=$(<"$token_file")
        token=$(printf '%s' "$token" | tr -d '\r\n')
        urlParam=$(auth)
        if [[ "$urlParam" == null || -z "$urlParam" ]]; then
            echo "Login not possible! Please check credentials and subscription for user $username."
            exit 1
        fi
    fi
    cleanup
}

download_url() {
    local ardPlusUrl="$1"
    local episode_skip="$2"
    local showPath showId content_variables seasonsStatus contentResult movie tvshow

    DOWNLOAD_FAIL_REASON=''
    showPath=$(echo "$ardPlusUrl" | rev | cut -d "/" -f1 | rev)
    showId=$(echo "$showPath" | cut -d "-" -f1)

    content_variables=$(jq -nc \
        --arg movieId "$showId" \
        '{movieId: $movieId, externalId: "", slug: "", potentialMovieId: ""}')
    if ! seasonsStatus=$(fetch_graphql "MovieDetails" "$GRAPHQL_MOVIE_DETAILS" "$content_variables" "$content_result"); then
        local metadata_error
        metadata_error=$(jq -r '.errors[0].message // empty' "$content_result" 2>/dev/null)
        if [[ -n "$metadata_error" ]]; then
            DOWNLOAD_FAIL_REASON="could not fetch content metadata (graphql: ${metadata_error})"
        else
            DOWNLOAD_FAIL_REASON="could not fetch content metadata (retries exhausted)"
        fi
        return 1
    fi

    contentResult=$(cat $content_result)
    movie=$(echo "$contentResult" | jq '.data.movie')
    tvshow=$(echo "$contentResult" | jq '.data.series')

    if [[ "$movie" != null ]]; then
        movieId=$(echo "$movie" | jq -r '.id')
        name=$(echo "$movie" | jq -r '.title // empty')
        videoUrl=$(echo "$movie" | jq -r '.videoSource.dashUrl')
        year=$(echo "$movie" | jq -r '.productionYear // empty')
        local safe_name
        safe_name=$(sanitize_path_component "$name")
        if [[ -n "$year" ]]; then
            filename="${safe_name} (${year})/${safe_name}"
        else
            filename="${safe_name}/${safe_name}"
        fi
        if skip_if_exists "$filename"; then
            return 0
        fi
        urlParam=$( auth )
        if [[ "$urlParam" == null || -z "$videoUrl" || "$videoUrl" == null ]]; then
            DOWNLOAD_FAIL_REASON="missing playback authorization or video URL for movie"
            cleanup
            return 1
        fi
        downloadUrl=${videoUrl}?${urlParam}
        log_msg "Lade Film ${filename}..."
        if ! run_yt_dlp "$downloadUrl" "$filename" "$name"; then
            cleanup
            return 1
        fi
        cleanup
        return 0
    elif [[ "$tvshow" != null ]]; then
        local requestedShow seasonIds seasonOutput selectedSeasonList selectedSeason safe_show
        requestedShow=$(echo "$contentResult" | jq -r '.data.series.title // empty')
        safe_show=$(sanitize_path_component "$requestedShow")
        seasonIds=$(echo "$contentResult" | jq '[.data.series.seasons.nodes[] | { season: .seasonInSeries, seasonId: .id, title: .title }]')
        seasonOutput=$(echo "$seasonIds" | jq '[.[] | { Option: .season, Titel: .title }]' | jq -r '(.[0]|keys_unsorted|(.,map(length*"-"))),.[]|map(.)|@tsv'|column -ts $'\t')
        log_msg ""
        log_msg "Gewünschte Serie: $requestedShow"
        log_msg ""
        log_msg "$seasonOutput"
        log_msg ""

        if [ $automatic_download -eq 0 ]; then
            echo -n "Welche Staffel möchtest du runterladen? "
            read -r selectedSeasonList
        else
            selectedSeasonList=$(echo "$seasonIds" | jq -r '.[].season')
        fi

        local apply_episode_skip=1
        for selectedSeason in $selectedSeasonList
        do
            local selectedSeasonId seasonData episodes amount selectedSeasonFormatted episode_line tail_from
            selectedSeasonId=$(echo "$seasonIds" | jq -r --argjson s "$selectedSeason" '.[] | select(.season == $s) | .seasonId')
            if [[ -z "$selectedSeasonId" || "$selectedSeasonId" == "null" ]]; then
                DOWNLOAD_FAIL_REASON="season ${selectedSeason} not found"
                return 1
            fi

            local season_result episode_status season_variables
            season_result=$(mktemp)
            season_variables=$(jq -nc --arg seasonId "$selectedSeasonId" '{seasonId: $seasonId}')
            if ! episode_status=$(fetch_graphql "EpisodesInSeasonData" "$GRAPHQL_EPISODES_IN_SEASON" "$season_variables" "$season_result"); then
                local episode_error
                episode_error=$(jq -r '.errors[0].message // empty' "$season_result" 2>/dev/null)
                rm -f "$season_result"
                if [[ -n "$episode_error" ]]; then
                    DOWNLOAD_FAIL_REASON="could not fetch episodes for season ${selectedSeason} (graphql: ${episode_error})"
                else
                    DOWNLOAD_FAIL_REASON="could not fetch episodes for season ${selectedSeason} (retries exhausted)"
                fi
                return 1
            fi
            seasonData=$(cat "$season_result")
            rm -f "$season_result"
            episodes=$(echo "$seasonData" | jq '[.data.episodes.nodes[]? | { id: .id, episodeNo: .episodeInSeason, title: .title, videoUrl: .videoSource.dashUrl }]')
            amount=$(echo "$episodes" | jq '. | length')
            if [[ "$amount" == "0" ]]; then
                DOWNLOAD_FAIL_REASON="no episodes returned for season ${selectedSeason}"
                return 1
            fi
            log_msg ""
            log_msg "Staffel $selectedSeason hat $amount Folgen."
            selectedSeasonFormatted=$(printf '%02d\n' "$selectedSeason")

            tail_from=1
            if [[ $episode_skip != "1" && $apply_episode_skip -eq 1 ]]; then
                tail_from=$((episode_skip + 1))
                log_msg "Überspringe $episode_skip Episode(n) in der ersten Staffel."
                apply_episode_skip=0
            fi

            while read -r episode_line
            do
                local name videoUrl episode filename urlParam downloadUrl safe_episode_title
                movieId=$(echo "$episode_line" | jq -r '.id')
                name=$(echo "$episode_line" | jq -r '.title // empty')
                videoUrl=$(echo "$episode_line" | jq -r '.videoUrl')
                episode=$(echo "$episode_line" | jq -r '.episodeNo // empty')
                safe_episode_title=$(sanitize_path_component "$name")
                if [[ -n "$episode" ]]; then
                    filename="${safe_show}/Season ${selectedSeasonFormatted}/${safe_show} S${selectedSeasonFormatted}E$(printf '%02d\n' "$episode") - ${safe_episode_title}"
                else
                    filename="${safe_show}/Season ${selectedSeasonFormatted}/${safe_show} S${selectedSeasonFormatted}E?? - ${safe_episode_title}"
                fi
                if skip_if_exists "$filename"; then
                    continue
                fi
                urlParam=$( auth )
                if [[ "$urlParam" == null || -z "$videoUrl" || "$videoUrl" == null ]]; then
                    DOWNLOAD_FAIL_REASON="missing playback authorization or video URL for ${filename}"
                    cleanup
                    return 1
                fi
                downloadUrl=${videoUrl}?${urlParam}
                log_msg "Lade ${filename}..."
                if ! run_yt_dlp "$downloadUrl" "$filename" "$filename"; then
                    cleanup
                    return 1
                fi
                cleanup
            done < <(echo "$episodes" | jq -c '.[]' | tail -n +"$tail_from")
        done
        return 0
    elif [[ "$ardPlusUrl" == *"tatort"* ]]; then
        local tatortCity tatortResponse tatortCityEpisodes amount cityCapitalized episode_line tatort_result
        tatort_result=$(mktemp)
        tatortCity=$(echo $showPath | cut -d "-" -f2)
        tatortResponse=$("$curlBin" -s "https://www.ardplus.de/kategorie/$showPath" \
        --header 'authority: data.ardplus.de' \
        --header 'content-type: application/json' \
        --header "cookie: sid=$token" \
        --header 'origin: https://www.ardplus.de' \
        --header 'referer: https://www.ardplus.de/' \
        --header 'user-agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36')

        tatortCityEpisodes=$(echo $tatortResponse | perl -0777 -ne 'print "$1\n" if /<script type="application\/ld\+json">\s*(.*?)\s*<\/script>/s')
        if [[ -z "$tatortCityEpisodes" ]]; then
            rm -f "$tatort_result"
            DOWNLOAD_FAIL_REASON="could not parse Tatort episode list from category page"
            return 1
        fi

        amount=$(echo $tatortCityEpisodes | jq '.itemListElement | length')
        cityCapitalized=$(echo ${tatortCity} | awk '{$1=toupper(substr($1,0,1))substr($1,2)}1')
        log_msg "Der Tatort ${cityCapitalized} hat $amount Episoden."
        if [ $automatic_download -eq 0 ]; then
            echo -n "Wie viele Episoden möchtest du überspringen? (0=alle laden) "
            read -r episode_skip
            log_msg "Überspringe $episode_skip Episode(n)."
        else
            episode_skip=0
        fi
        episode_skip=$((episode_skip + 1))

        while read -r episode_line
        do
            local episodeId episode_variables episodeDetailsStatus episodeDetails name videoUrl year customData episode team city filename urlParam downloadUrl safe_name safe_city safe_team
            episodeId=$(echo "$episode_line" | jq -r '.item.url' | sed -E 's#.*/details/([^/-]+).*#\1#')
            episode_variables=$(jq -nc \
                --arg movieId "$episodeId" \
                '{movieId: $movieId, externalId: "", slug: "", potentialMovieId: ""}')

            if ! episodeDetailsStatus=$(fetch_graphql "MovieDetails" "$GRAPHQL_MOVIE_DETAILS" "$episode_variables" "$tatort_result"); then
                local tatort_error
                tatort_error=$(jq -r '.errors[0].message // empty' "$tatort_result" 2>/dev/null)
                if [[ -n "$tatort_error" ]]; then
                    DOWNLOAD_FAIL_REASON="could not fetch Tatort episode details (graphql: ${tatort_error})"
                else
                    DOWNLOAD_FAIL_REASON="could not fetch Tatort episode details (retries exhausted)"
                fi
                rm -f "$tatort_result"
                return 1
            fi

            episodeDetails=$(cat "$tatort_result")
            movieId=$(echo "$episodeDetails" | jq -r '.data.movie.id')
            name=$(echo "$episodeDetails" | jq -r '.data.movie.title // empty')
            videoUrl=$(echo "$episodeDetails" | jq -r '.data.movie.videoSource.dashUrl')
            year=$(echo "$episodeDetails" | jq -r '.data.movie.productionYear // empty')
            customData=$(echo "$episodeDetails" | jq '.data.movie.customData // {}')
            episode=$(echo "$customData" | jq -r '.episodeProductionNumber // empty')
            team=$(echo "$customData" | jq -r '.team // empty')
            city=$(echo "$customData" | jq -r '.location // empty')
            safe_city=$(sanitize_path_component "$city")
            safe_team=$(sanitize_path_component "$team")
            safe_name=$(sanitize_path_component "$name")
            filename="Tatort ${safe_city}"
            if [[ -n "$team" ]]; then
                filename="$filename (${safe_team})"
            fi
            if [[ -n "$episode" ]]; then
                filename="$filename - Folge ${episode}"
            fi
            if [[ -n "$year" ]]; then
                filename="$filename - ${safe_name} (${year})"
            else
                filename="$filename - ${safe_name}"
            fi
            if skip_if_exists "$filename"; then
                continue
            fi
            urlParam=$( auth )
            if [[ "$urlParam" == null || -z "$videoUrl" || "$videoUrl" == null ]]; then
                DOWNLOAD_FAIL_REASON="missing playback authorization or video URL for ${filename}"
                cleanup
                rm -f "$tatort_result"
                return 1
            fi
            downloadUrl=${videoUrl}?${urlParam}
            log_msg "Lade ${filename}..."
            if ! run_yt_dlp "$downloadUrl" "$filename" "$filename"; then
                cleanup
                rm -f "$tatort_result"
                return 1
            fi
            cleanup
            sleep 1
        done < <(echo "$tatortCityEpisodes" | jq -c '.itemListElement[]' | tail -n +$episode_skip )
        rm -f "$tatort_result"
        return 0
    else
        if [[ -n "$(echo "$contentResult" | jq -r '.errors[0].message // empty')" ]]; then
            DOWNLOAD_FAIL_REASON="graphql API error: $(echo "$contentResult" | jq -r '.errors[0].message')"
        else
            DOWNLOAD_FAIL_REASON="invalid content (no movie or series in API response)"
        fi
        log_msg "$DOWNLOAD_FAIL_REASON"
        return 1
    fi
}

# intercept CTRL+C click to clean up before exit
term() {
    echo "CTRL+C pressed. Cleanup and exit!"
    cleanup
    rm -f $content_result
    exit 0
}

main() {
# parse input parameters
while [[ $# -gt 0 ]]; do
    case "$1" in
        --automatic)
            automatic_download=1
            shift
            ;;
        --links-file)
            if [[ -z "$2" || "$2" == -* ]]; then
                echo "Error: --links-file requires a file argument" >&2
                exit 1
            fi
            batch_mode=1
            links_file=$2
            shift 2
            ;;
        --force-redownload)
            skip_existing_files=0
            shift
            ;;
        *)
            break
            ;;
    esac
done

if [[ $batch_mode -eq 1 ]]; then
    username=$1
    password=$2
    skip=$3
else
    ardPlusUrl=$1
    username=$2
    password=$3
    skip=$4
fi
movieId=''
token=''

if [[ -z "$username" || -z "$password" ]]; then
    echo "Credentials missing! Please start the script with:"
    echo "  ./ard-plus-dl.sh [--automatic] [--links-file <file>] <ard-plus-url> <username> <password>"
    echo "  ./ard-plus-dl.sh [--automatic] --links-file <file> <username> <password>"
    exit 1
fi

if [[ $batch_mode -eq 1 ]]; then
    if [[ -z "$links_file" || ! -f "$links_file" ]]; then
        echo "Links file missing or not found: $links_file"
        exit 1
    fi
    automatic_download=1
    links_dir=$(cd "$(dirname "$links_file")" && pwd)
    links_file="$links_dir/$(basename "$links_file")"
elif [[ -z "$ardPlusUrl" ]]; then
    echo "URL or --links-file required."
    exit 1
fi

if [[ -z "$skip" ]]; then
    skip=1
fi

work_dir=$(pwd)
if [[ $batch_mode -eq 1 ]]; then
    work_dir="$links_dir"
fi
downloads_dir="${DOWNLOADS_DIR:-${work_dir}/downloads}"
mkdir -p "$downloads_dir"

resolve_token_file

content_result=$(mktemp)
RUN_TS=$(date +%Y-%m-%d_%H-%M-%S)

if [[ $batch_mode -eq 1 ]]; then
    logs_dir="$links_dir/logs"
    mkdir -p "$logs_dir"
    SUCCESS_FILE="$logs_dir/successful_links_${RUN_TS}.txt"
    FAILED_FILE="$logs_dir/failed_links_${RUN_TS}.txt"
    LOG_FILE="$logs_dir/download_log_${RUN_TS}.txt"
    touch "$SUCCESS_FILE" "$FAILED_FILE" "$LOG_FILE"
fi
trap term SIGINT

ensure_token

echo "Downloads directory: ${downloads_dir}"

if [[ $batch_mode -eq 1 ]]; then
    log_msg "Batch download started at ${RUN_TS}"
    log_msg "Links file: ${links_file}"
    log_msg "Downloads directory: ${downloads_dir}"
    log_msg "Logs directory: ${logs_dir}"
    log_msg "Download log: ${LOG_FILE}"
    log_msg "Success log: ${SUCCESS_FILE}"
    log_msg "Failed log: ${FAILED_FILE}"
    log_msg ""

    while IFS= read -r link_line || [[ -n "$link_line" ]]; do
        link_line="${link_line%%#*}"
        link_line="${link_line%"${link_line##*[![:space:]]}"}"
        link_line="${link_line#"${link_line%%[![:space:]]*}"}"
        [[ -z "$link_line" ]] && continue

        normalized_link=$(normalize_url "$link_line")
        log_msg "Processing: ${normalized_link}"

        if download_url "$normalized_link" "$skip"; then
            record_success "$normalized_link"
        else
            if [[ -z "$DOWNLOAD_FAIL_REASON" ]]; then
                DOWNLOAD_FAIL_REASON="unknown error"
            fi
            record_failure "$normalized_link" "$DOWNLOAD_FAIL_REASON"
        fi
        log_msg ""
    done < "$links_file"

    log_msg "Batch download finished."
    log_msg "Logs directory: ${logs_dir}"
    log_msg "Successful links: ${SUCCESS_FILE}"
    log_msg "Failed links: ${FAILED_FILE}"
else
    if download_url "$ardPlusUrl" "$skip"; then
        cleanup
    else
        cleanup
        exit 1
    fi
fi

rm -f $content_result
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
