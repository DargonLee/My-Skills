# Template Extension

This skill is designed to scale from the current bundled iOS Pod and RN templates to future Android and Harmony templates.

## Add A New Template Pack

1. Create a new folder under `assets/templates/<template-id>/`.
2. Put the raw template files in `assets/templates/<template-id>/template/`.
3. Add `assets/templates/<template-id>/manifest.json`.
4. Reuse the same generator script. Do not fork the generation logic unless the template truly needs a new behavior.

## Manifest Shape

```json
{
  "id": "rn-module",
  "platform": "react-native",
  "kind": "module",
  "display_name": "React Native Module",
  "description": "Team React Native module scaffold.",
  "source_dir": "template",
  "target_dir_template": "{{module_name}}",
  "rename_tokens": {
    "<#template1#>": "{{module_name}}"
  },
  "content_tokens": {
    "<#template1#>": "{{module_name}}",
    "<#template2#>": "{{module_name_kebab}}"
  },
  "ignore_names": [
    ".DS_Store"
  ]
}
```

## Supported Variables

- `module_name`: original module name from the command.
- `module_name_kebab`: `MyModule` -> `my-module`.
- `module_name_snake`: `MyModule` -> `my_module`.
- `module_name_lower`: lowercase module name.
- `module_name_upper`: uppercase module name.
- Custom variables passed through `--var key=value`.

## Platform Notes

- React Native templates usually need both `module_name` and `module_name_kebab`.
- Android templates often need extra variables such as `package_name`, `namespace`, or `application_id`.
- Harmony templates may need bundle names, package identifiers, or ArkTS-specific placeholders.

When a template needs those values, add placeholder tokens in `manifest.json` and pass the values through `--var`.

## Practical Examples

### React Native

Use content placeholders such as:

- `<#template1#>` -> `{{module_name}}`
- `<#template2#>` -> `{{module_name_kebab}}`

### Android

Typical mappings:

- `__MODULE_NAME__` -> `{{module_name}}`
- `__PACKAGE_NAME__` -> `{{package_name}}`
- `__NAMESPACE__` -> `{{namespace}}`

### Harmony

Typical mappings:

- `__MODULE_NAME__` -> `{{module_name}}`
- `__BUNDLE_NAME__` -> `{{bundle_name}}`
- `__ENTRY_ABILITY__` -> `{{entry_ability}}`

## Recommendation

Keep each platform pack self-contained:

- Template assets under `assets/templates/<template-id>/template/`
- One `manifest.json` per pack
- No platform-specific branching in `SKILL.md`

That keeps the skill stable while templates evolve independently.
