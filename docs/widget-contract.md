# The widget contract

A Rubylode plugin puts its block on the Status page by registering a widget. The Status plugin draws what is registered and
never reads another plugin's settings: whatever it needs, the plugin hands over in the registration.

## Register

Put this at the end of the plugin's `init.rb`, after `Redmine::Plugin.register`. Beszel as the example:

```ruby
# Puts the block on the Status page when Rubylode Status is installed. See its docs/widget-contract.md.
Rails.application.config.after_initialize do
  if defined?(RubylodeStatus::Registry)
    RubylodeStatus::Registry.register(
      key: "beszel",
      title: -> { RubylodeBeszel::Settings.current.block_title },
      path: "/status/beszel",
      data: -> { RubylodeBeszel::StatusWidget.data },
      partial: "rubylode_beszel/status",
      visibility: -> { RubylodeBeszel::Settings.current.visibility }
    )
  end
end
```

Why `after_initialize`: Redmine loads plugins in alphabetical order, so `redmine_rubylode_beszel` runs its `init.rb` before
`redmine_rubylode_status` does. At boot the block above waits until every plugin is loaded. After a code reload in development
it runs at once, and registering the same key again replaces the widget. Without the Status plugin `defined?` is false and
nothing happens.

Don't use `Rails.application.config.to_prepare` for this. Redmine runs every plugin's `init.rb` inside its own `to_prepare`
callback, so a `to_prepare` block added from `init.rb` is never called at boot. I checked both on Redmine 7.0.2, in the test
and the production environment, with plugins named to load before and after this one.

## The arguments

| Argument | Required | What it is |
|---|---|---|
| `key` | yes | The plugin's short name from the standard: `beszel`, `glitchtip`, `uptime_kuma`, `windmill`. Lowercase letters, digits and `_`, starting with a letter. |
| `title` | yes | The block title setting. A string, or a callable that returns one; a callable is asked each time the page is drawn. |
| `path` | yes | The path of the plugin's own page, `/status/<short_name>`. The block title links there. A string or a callable. |
| `data` | yes | A callable with no arguments that returns the block's data (below). Anything else raises `ArgumentError` at boot. |
| `partial` | no | A partial that draws the body of the block in place of the plain list of items, for example `rubylode_beszel/status`. |
| `visibility` | no | `"logged_in"` (everyone signed in, the default) or `"admins"` (administrators only), or a callable that returns one. Anything else counts as administrators only. |

A key that is not a short name raises `ArgumentError` at boot, so a typo shows up in the plugin's own tests.

## The data

`data` returns a hash, with symbol or string keys:

```ruby
{
  state: "warning",              # ok, warning, down or unknown
  summary: "1 of 3 servers busy", # one line
  items: [
    { name: "web-1", state: "warning", detail: "CPU 91%" },
    { name: "db-1", state: "ok", detail: nil }
  ]
}
```

- A state that is not one of the four becomes `unknown`, for the block and for each item.
- The summary is kept to one line: line breaks become spaces.
- `items` may be empty or missing. `detail` is optional.
- Other keys are kept and reach the partial as `status.data`, so a partial can draw more than the contract lists.

The page asks each block once per visit, one after another. Cache upstream answers in the plugin; the Status plugin caches
nothing.

## When a block fails

The page never breaks because of one block:

- `data` raises: the block shows Unknown with "This block could not be loaded. The error is in the Redmine log." The log line
  starts with `Rubylode Status: the <key> block failed`. The error message stays out of the page, since it may name hosts.
- `data` takes longer than the Timeout seconds setting (5 by default): Unknown, "This block did not answer within 5 seconds."
  A plugin's own network timeout counts as a failure, not as this.
- `data` returns something other than a hash: Unknown, "This block returned nothing to show."
- The partial raises: the block keeps its title, state and summary, and its body says "This block could not be drawn. The error
  is in the Redmine log."

## The partial

The partial gets two locals:

- `widget`: the registered widget (`widget.key`, `widget.title`, `widget.path`).
- `status`: what the block reported, after the checks above (`status.state`, `status.summary`, `status.items`, and
  `status.data`, the hash `data` returned, with symbol keys).

The Status page draws the title, the state and the summary itself. The partial draws only what goes under them. When `data`
failed, the partial is skipped and the page shows the message.

## Visibility

The page and `/status.json` leave out a block the viewer may not see, and the Status link in the top menu is shown only to
people who may see at least one block. Someone holding the read-only status token sees the blocks for everyone signed in,
never the administrators-only ones.

## Drop your own top menu item

With the Status plugin installed the block lives on the Status page, so the plugin's own top menu item goes:

```ruby
menu :top_menu, :rubylode_beszel_status, { controller: "rubylode_beszel_status", action: "show" },
     caption: proc { RubylodeBeszel::Settings.current.block_title },
     if: proc { !Redmine::Plugin.installed?(:redmine_rubylode_status) && RubylodeBeszel::Settings.current.show_in_top_menu? }
```

Hide the `show_in_top_menu` setting under the same condition.

## The notice on the plugin's settings page and its own page

Paste these sentences as they are, so every plugin says the same thing. When the Status plugin is missing:

> Install [Rubylode Status](https://github.com/rubylode/redmine-rubylode-status) to see this with the other status blocks on one page.

When it is installed:

> Rubylode Status is installed, so this block shows on the [Status page](/status).

In ERB, with the plugin's locale root. Rails' `t` keeps the link as a link in a key that ends in `_html`; Redmine's `l` would escape it:

```erb
<p class="rubylode-status-notice">
  <% if Redmine::Plugin.installed?(:redmine_rubylode_status) %>
    <%= t("rubylode_beszel.status_plugin.installed_html", link: link_to(t("rubylode_beszel.status_plugin.status_page"), "/status")) %>
  <% else %>
    <%= t("rubylode_beszel.status_plugin.missing_html", link: link_to("Rubylode Status", "https://github.com/rubylode/redmine-rubylode-status")) %>
  <% end %>
</p>
```

```yaml
en:
  rubylode_beszel:
    status_plugin:
      missing_html: "Install %{link} to see this with the other status blocks on one page."
      installed_html: "Rubylode Status is installed, so this block shows on the %{link}."
      status_page: Status page
```

## What `/status.json` makes of it

Each block becomes one entry of `widgets`, in page order:

```json
{ "key": "beszel", "title": "Servers", "state": "warning", "summary": "1 of 3 servers busy",
  "items": [{ "name": "web-1", "state": "warning", "detail": "CPU 91%" }], "path": "/status/beszel" }
```

`status.data` keys beyond the contract are not in the JSON.
