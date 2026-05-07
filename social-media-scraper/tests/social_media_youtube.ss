import { youtubeSubtitles } from "../scripts/social-media-scraper.ss"

mockHttpRequest = (method: string, path: string): { status: number, body: string } => {
  isDetails = stringIncludes({ haystack: path, needle: "/video/details" }).result
  isSubtitle = stringIncludes({ haystack: path, needle: "/video/subtitles" }).result

  result = isDetails
    ? { status: 200, body: "{\"subtitles\":{\"items\":[{\"code\":\"en\",\"url\":\"https://example.com/sub.vtt\"}]}}" }
    : isSubtitle
    ? { status: 200, body: "1\n00:00:01,000 --> 00:00:05,000\nHello world\n" }
    : { status: 400, body: "unknown" }

  return result
}

fetchesSubtitlesForValidUrl = () => {
  f = override(youtubeSubtitles, { httpRequest: mockHttpRequest })
  result = f({ rapidApiKey: "key", url: "https://youtube.com/watch?v=abc123" })
  assert({ condition: result.success, message: "should fetch subtitles for valid URL" })
  assert({ condition: stringIncludes({ haystack: result.result, needle: "Hello world" }).result, message: "result should contain subtitle text" })
  return true
}

rejectsUrlWithoutVideoId = () => {
  f = override(youtubeSubtitles, { httpRequest: mockHttpRequest })
  result = f({ rapidApiKey: "key", url: "https://youtube.com/not-a-video" })
  assert({ condition: result.success ? false : true, message: "should reject URL without video ID" })
  return true
}
