# rules/

Custom Wazuh detection rules for the SOC lab.

## What lives here

- `local_rules.xml` -- a repo copy of the custom rules you deploy to the manager at
  `/var/ossec/etc/rules/local_rules.xml`. Keeping a copy here is what makes the detection
  engineering visible in the GitHub portfolio.

## Rules of the road

- **ID range:** custom rules use 100000+. The worked examples in
  `../docs/guides/Blue_Team_Home_Lab_Guide.md` (Section 4) already use 100001-100014, so
  **start your rules at 100015**.
- **Syntax:** reuse the patterns in that guide's Section 4.2 (`<if_sid>`,
  `<field name="..." type="pcre2">`, `<mitre>`, `<group>`). Do not invent syntax.
- **Always validate** before trusting a rule: `sudo /var/ossec/bin/wazuh-logtest`.
- **Always back up** before editing the live file:
  `sudo cp /var/ossec/etc/rules/local_rules.xml /var/ossec/etc/rules/local_rules.xml.backup`
  (a syntax error stops the manager from starting and takes the whole dashboard down).

See `../docs/Signature_Project_Detection_Gap.md` Step 3 for the full procedure and the
common rule-writing failure modes.
