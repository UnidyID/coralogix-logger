## [Unreleased]

## [0.1.1] - 2025-01-19

### Fixed
- Fixed sender thread not restarting after process fork (Puma/Unicorn compatibility)
- Fixed HttpSender not being recreated after fork, preventing stale connections
- Fixed race condition in `send_bulk` by moving buffer empty check inside mutex
- Fixed Manager using incorrect local constants instead of module-level constants from `constants.rb`
  - Send intervals now correctly use 0.5s/0.1s instead of 5s/1s

### Added
- Added startup log message when logger is configured (aids debugging connectivity)
- Added `disable_proxy` option to `Coralogix.configure`
- Added `Coralogix.version` method for version reporting

## [0.1.0] - 2024-11-21

- Initial release
