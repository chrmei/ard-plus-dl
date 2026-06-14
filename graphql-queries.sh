# GraphQL query strings for ARD Plus (POST, no persisted-query hashes).

GRAPHQL_MOVIE_DETAILS='query MovieDetails($movieId: String!, $externalId: String!, $slug: String!, $potentialMovieId: String!) {
  movie: getMovieDetails(idList: [$movieId, $potentialMovieId, $externalId, $slug]) {
    id
    title
    productionYear
    customData
    videoSource {
      dashUrl
    }
  }
  series: getSeriesDetails(idList: [$movieId, $potentialMovieId, $externalId, $slug]) {
    title
    seasons: cmsSeasonsBySeriesId(orderBy: SEASON_IN_SERIES_ASC) {
      nodes {
        id
        title
        seasonInSeries
      }
    }
  }
}'

GRAPHQL_EPISODES_IN_SEASON='query EpisodesInSeasonData($seasonId: Guid!) {
  episodes: allCmsEpisodes(condition: { seasonId: $seasonId }, orderBy: EPISODE_IN_SEASON_ASC) {
    nodes {
      id
      episodeInSeason
      title
      videoSource {
        dashUrl
      }
    }
  }
}'
