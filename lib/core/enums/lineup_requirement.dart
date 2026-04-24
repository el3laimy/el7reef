/// Controls whether a match requires official lineup snapshots before start.
///
/// - [none]: Pickup friendly — no lineup needed.
/// - [optional]: Friendly with teams — lineup is available but not mandatory.
/// - [required]: Tournament match — lineup must be locked before kickoff.
enum LineupRequirement { none, optional, required }
