# Creating Data Streams

EnhanceQoL includes a **DataPanel** system backed by a DataHub to share information between modules. Streams describe how data is collected and formatted and can be displayed inside configurable panels.

## Stream provider template

`Streams/Template.lua` contains a minimal provider.  Every provider must define the following fields:

- `id` – unique identifier for the stream.
- `version` – number increased whenever the provider changes.
- `title` – human readable name shown to users.
- `columns` – list of column definitions (each with at least a `key` and `title`).
- `poll` – number of seconds between calls to `collect`.
- `collect` – function that populates `ctx.rows` for the snapshot (returns nothing).

Optional fields:

- `filter` – return `false` to skip a row.
- `actions` – table of custom callbacks exposed to consumers.
- `settings` – default configuration values for the stream.
- `OnClick` – function or table of button-specific handlers used for the panel button.

## Registering a stream

After defining a provider, register it with the DataHub:

```lua
local provider = require("Streams.MyStream")
EnhanceQoL.DataHub.RegisterStream(provider)
```

`RegisterStream` makes the stream available to the addon so other modules and DataPanels can subscribe to it.

## Creating your own stream

1. Copy `Streams/Template.lua` to a new file inside the `Streams/` directory and rename it.
2. Fill in the required fields with values appropriate for your data.
3. Implement the `collect` function to gather data and populate `ctx.rows` using `ctx.acquireRow`.
4. Optionally add `filter`, `actions`, `settings`, or `OnClick`.
5. Register the provider using `EnhanceQoL.DataHub.RegisterStream` during addon startup.

Once registered, the DataHub will invoke `collect` at the interval defined by `poll` and distribute snapshot updates to any subscribers. Streams may then be added to panels with `/eqolpanel add <panel> <stream>`.
