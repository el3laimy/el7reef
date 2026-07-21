/// Controls whether a match requires official lineup snapshots before start.
///
/// - [none]: Pickup friendly — no lineup needed.
/// - [optional]: Friendly with teams — lineup is available but not mandatory.
/// - [required]: Explicit competition rule requiring a locked lineup.
enum LineupRequirement { none, optional, required }
