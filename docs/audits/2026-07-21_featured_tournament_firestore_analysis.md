# Featured tournament Firestore analysis

- Target: `(default)` Firestore database, Standard edition, project `el7reef-app`, region `nam5`.
- Public catalog query: authenticated clients list `tournaments` where `visibility == public` and `discoverable == true`; active catalog also filters `status` and orders by `createdAt`.
- Featured catalog addition: a second authenticated query filters `isFeatured == true`; client merges it with the active catalog so featured completed tournaments remain visible.
- Tournament document additions: `isFeatured` (`bool`) and `featuredPriority` (`int`, 0..1000). Legacy documents read as `false` and `1000`.
- Client writes: organizers create and update tournament documents. They must be forced to create unfeatured tournaments and preserve existing featured metadata on update.
- Administrative writes: the World Cup production publisher uses Admin SDK, explicit project confirmation, collision checks, and catalog-only updates.
- Reads remain authenticated. No unauthenticated tournament read or list access is introduced.
- Required indexes: existing active public catalog index remains; featured public catalog needs `discoverable`, `visibility`, `isFeatured`, and `featuredPriority`.
- Related public data paths used by the viewer flow: tournament participants, groups, standings, matches, knockout bracket/ties, guest teams, and guest players. Existing rules require authentication for these reads.
