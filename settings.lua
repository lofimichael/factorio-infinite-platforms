-- Runtime mod settings (global only - player settings moved to GUI)

data:extend({
  -- Check interval for starter pack availability
  {
    type = "int-setting",
    name = "spa-check-interval",
    setting_type = "runtime-global",
    default_value = 300,
    minimum_value = 60,
    maximum_value = 3600,
    order = "a"
  }
})
