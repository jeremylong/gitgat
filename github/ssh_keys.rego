package github.ssh_keys

import future.keywords.in
import data.github.utils as utils

rule_set = input.rule_set { utils.exists(input, "rule_set") } else := data.rule_set

# Keys
responses := utils.parse(data.github.api.call_github("user/keys")) {
  rule_set == "user"
}

# [ { "key": "ssh-rsa ..." } ]
user_keys := utils.flatten_array(responses, "key")
keys := utils.array_subtraction(user_keys, data.github.state.ssh_keys.keys)

expired[k.id] = v {
  k := responses[_]
  utils.is_expired(k, data.github.state.ssh_keys.expiration)
  v := json.filter(k, ["created_at"])
}

keys_findings = v {
  valid := count(keys) - count(expired)
  valid > 1
  c_findings := "(i) You have %d valid SSH keys."
  v := sprintf(c_findings, [valid])
}

keys_findings = v {
  valid := count(keys) - count(expired)
  valid == 1
  v := "(i) You have 1 valid SSH key."
}

keys_findings = v {
  valid := count(keys) - count(expired)
  valid == 0
  v := "(i) You have no valid SSH keys."
}

keys_findings = v {
  count(keys) == 0
  v := "(v) no new keys."
}

expired_findings = v {
  count(expired) == 0
  v := "(v) no keys have expired."
}

expired_findings = v {
  count(expired) == 1
  v := "(i) You have 1 expired key."
}

expired_findings = v {
  count(expired) > 1
  c_findings := "(i) You have %d expired keys."
  v := sprintf(c_findings, [count(expired)])
}

eval = v {
  v := { "state": {"expired": expired, "keys": keys},
         "processing_errors": { k: v | some k; v := responses[k]; utils.is_error(v) },
  }
}

findings := concat("\n", [keys_findings, expired_findings])

report := [
  "## SSH Keys",
  "### Motivation",
  "SSH keys are an authentication tool that enables tools like git to access repositories you have access to.",
  "In GitHub personal and organizational accounts, SSH keys are managed by the user.",
  "Thus the following are findings regarding *your* SSH keys.",
  "",

  "### Key Findings",
  "%s",
  "",

  "### Our Recommendation",
  "Your SSH keys allow full access to all the repositories over SSH.",
  "We recommend you review your SSH keys regularly; ensure you are familiar with the keys and their use.",
  "In case of an upcoming expiration date - ensure you replace the keys on time.",
  "SSH keys generation is done via the following link: <https://github.com/settings/keys>",
  "",
]

overview_report := v {
  c_report := concat("\n", report)
  v := sprintf(c_report, [findings])
}
