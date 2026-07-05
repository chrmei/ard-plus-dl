# Bug: `sed 's/\\"//g'` corrupts episode titles containing quotes

## Description

The episode loop pipes the JSON episode list through `sed` before `jq`:

```bash
done < <(echo "$episodes" | sed 's/\\"//g' | jq -c '.[]' | tail -n +$episode_skip)
```

The `sed` expression deletes every escaped quote (`\"`) from the raw JSON. That means any episode title that legitimately contains double quotes is silently altered before it is parsed.

## Reproduction

```bash
echo '[{"title":"Say \"Hi\" Ep"}]' | sed 's/\\"//g' | jq -c '.[]'
# -> {"title":"Say Hi Ep"}    (quotes silently removed)
```

The resulting filename no longer matches the real title, and if a title ever contained `\\\"` or similar sequences the stripped JSON could even become invalid and abort the season with a jq parse error.

## Suggested fix

Remove the `sed` stage entirely — `jq -c '.[]'` already emits one valid JSON object per line, and each field is re-extracted with `jq -r` afterwards, so no manual unescaping is needed:

```bash
done < <(echo "$episodes" | jq -c '.[]' | tail -n +"$episode_skip")
```

Also add `-r` to the `while read` loops (shellcheck SC2162) so backslashes in the JSON are not mangled by `read` itself.

Labels: `bug`
