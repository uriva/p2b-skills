import { isLinkedInUrl } from "../scripts/social-media-scraper.ss"

acceptsValidLinkedInUrl = () => {
  result = isLinkedInUrl({ url: "https://www.linkedin.com/in/uriv/" })
  assert({ condition: result, message: "valid LinkedIn URL should be accepted" })
  return true
}

acceptsWithoutWww = () => {
  result = isLinkedInUrl({ url: "https://linkedin.com/in/uriv" })
  assert({ condition: result, message: "LinkedIn URL without www should be accepted" })
  return true
}

rejectsNonLinkedInUrl = () => {
  result = isLinkedInUrl({ url: "not-a-url" })
  assert({ condition: result ? false : true, message: "non-LinkedIn URL should be rejected" })
  return true
}

rejectsNestedPath = () => {
  result = isLinkedInUrl({ url: "https://www.linkedin.com/in/uriv/details" })
  assert({ condition: result ? false : true, message: "URL with extra path should be rejected" })
  return true
}
