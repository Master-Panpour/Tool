# Aegiscope plugin contract

Each reviewed `plugins/<name>.sh` adapter declares `AEGIS_PLUGIN_NAME`,
`AEGIS_PLUGIN_DESCRIPTION`, and these functions:

- `aegis_plugin_check`
- `aegis_plugin_build_command`
- `aegis_plugin_execute`
- `aegis_plugin_normalize`
- `aegis_plugin_artifacts`

Plugins run with the operator's permissions. Treat them as executable code,
review changes, and keep them inside the authorized assessment workflow.
