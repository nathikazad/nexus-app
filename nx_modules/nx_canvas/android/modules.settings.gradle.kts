val canvasRoot = file(extra["canvasRoot"] as String)
for (module in listOf("model", "engine", "platform", "recovery", "diagnostics", "firmware", "rendering", "editor")) {
    include(":canvas-$module")
    project(":canvas-$module").projectDir = canvasRoot.resolve(module)
}
include(":vendor-api")
project(":vendor-api").projectDir = canvasRoot.resolve("vendor-api")
include(":canvas-validation")
project(":canvas-validation").projectDir = canvasRoot.resolve("validation")
