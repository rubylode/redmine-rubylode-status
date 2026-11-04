# Changelog

All notable changes to this plugin. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [2.0.0] - 2026-11-04

First release. It starts at 2.0.0 with the rest of the Rubylode 2.0 plugins. Redmine 7.0 and newer.

### Added

- A registry other Rubylode plugins put their status block in: a key, a title, the path of their own page, a callable for
  the data (a state, a one-line summary and items), an optional partial, and who may see it. The contract is in
  `docs/widget-contract.md`.
- The Status page at `/status`, with every registered block the viewer may see. A block that raises, takes too long or
  returns nothing shows as Unknown, and the rest of the page still draws.
- One top menu link for it, named by the Menu label setting (default Status), for people who may see at least one block.
- Settings for the order of the blocks, whether each is shown, and its column.
- `/status.json`: Redmine's version, whether its database answers, and the blocks. It takes a signed-in session, a Redmine API
  key, or an optional read-only token from the `STATUS_TOKEN` environment variable.
- An empty page that names the plugins that can register a block.
