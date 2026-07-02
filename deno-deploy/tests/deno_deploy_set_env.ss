import { setDenoDeployEnvVar } from "../scripts/deno-deploy.ss"

mockPatchOk = (host, method, path, headers, body) => {
  isPatch = method == "PATCH"
  hasKey = stringIncludes({ haystack: body, needle: "NEXT_PUBLIC_APP_ID" }).result
  status = isPatch ? (hasKey ? 200 : 400) : 404
  return { status: status, body: "{\"slug\":\"my-app\",\"env_vars\":[{\"key\":\"NEXT_PUBLIC_APP_ID\",\"value\":\"abc123\"}]}" }
}

setsEnvVarViaPatch = () => {
  f = override(setDenoDeployEnvVar, { httpRequest: mockPatchOk })
  res = f({ denoDeployToken: "ddo_test", appSlug: "my-app", key: "NEXT_PUBLIC_APP_ID", value: "abc123", isSecret: false })
  assert({ condition: res.success == true, message: "expected success setting env var via PATCH" })
  assert({ condition: stringIncludes({ haystack: res.result, needle: "NEXT_PUBLIC_APP_ID" }).result, message: "expected the returned app body to include the env var key" })
  return true
}

mockPatchError = (host, method, path) => {
  return { status: 404, body: "{\"message\":\"app not found\"}" }
}

failsWhenAppMissing = () => {
  f = override(setDenoDeployEnvVar, { httpRequest: mockPatchError })
  res = f({ denoDeployToken: "ddo_test", appSlug: "missing-app", key: "K", value: "V", isSecret: false })
  assert({ condition: res.success == false, message: "expected failure when app is missing" })
  assert({ condition: stringIncludes({ haystack: res.error, needle: "DENO_DEPLOY_SET_ENV_ERROR" }).result, message: "expected DENO_DEPLOY_SET_ENV_ERROR in the error" })
  return true
}
