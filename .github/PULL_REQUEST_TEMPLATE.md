## Summary

- What changed in this PR?
- Why is this change needed?

## Scope

- [ ] UI / interaction
- [ ] data model / storage
- [ ] import / export / parser
- [ ] notification / widget
- [ ] windows runner / mini mode
- [ ] docs only

## Related Issue

- Closes #<issue-id> (if any)

## Version Impact

- [ ] No version change needed
- [ ] `tool/version_config.yaml` updated
- [ ] `dart run tool/sync_version.dart` executed

## Testing

- [ ] `flutter analyze`
- [ ] `flutter test`
- [ ] Android manual test completed
- [ ] Windows manual test completed
- [ ] iOS manual test completed (if relevant)

Manual test notes:

1.
2.
3.

## Parser / Import Change Notes

If this PR changes timetable import, grade import, Excel import, ICS import, or payload parsing:

- [ ] I validated with real or representative samples
- [ ] I documented the sample shape or failure mode
- [ ] I updated `docs/UPSTREAM_ATTRIBUTION.md` if third-party logic/reference was involved

## Risk / Compatibility

- Does this change affect storage schema, semester switching, reminders, widget sync, or Windows mini mode?
- Any rollback plan needed?

## Docs Checklist

- [ ] `README.md` updated if user-visible behavior changed
- [ ] `docs/` updated if developer workflow changed
- [ ] `agent_handoff/` updated if the next AI would otherwise miss important context

## Attribution / License Check

- [ ] No third-party code involved
- [ ] Third-party code involved and attribution has been updated

## Security / Privacy

- [ ] No secrets included
- [ ] No cookie / token / account data committed
- [ ] Any parser sample included in the PR has been desensitized
