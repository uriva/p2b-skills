---
name: p2b-make
description: Make.com integration guidance for prompt2bot agents — regional APIs, module versions, and scenario blueprint scanning.
---

# p2b-make

Make.com integration skill for prompt2bot agents.

## Instructions

When building or editing Make.com scenarios programmatically via the API:

- Make runs on regional subdomains: `eu1.make.com`, `eu2.make.com`, `us1.make.com`.
  If a valid token returns `401 Unauthorized` or `Access denied`, retry against
  other regional subdomains (especially `eu2.make.com`) before assuming the token
  is broken.

- **Module versions — scan before injecting.** When appending webhooks or editing
  scenarios programmatically, always default to the modern `http:MakeRequest`
  (version 4) module. Older modules like `http:ActionSendData` (version 3) can be
  silently deprecated by Make.com and cause `BundleValidationError` that pauses
  the scenario. Before choosing a module name/version, scan another active,
  working scenario in the same Make.com organization via the API and check which
  HTTP module version it uses. Use that verified version in your blueprint
  instead of guessing.
