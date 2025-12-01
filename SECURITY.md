# Security Policy

## Supported Versions

We release patches for security vulnerabilities in the following versions:

| Version | Supported          |
| ------- | ------------------ |
| 1.x.x   | :white_check_mark: |

## Reporting a Vulnerability

We take security seriously at Dream Test. If you discover a security vulnerability, please report it responsibly.

### How to Report

**Please do not report security vulnerabilities through public GitHub issues.**

Public issues are visible to everyone, which means disclosing a vulnerability there could allow malicious actors to exploit it before we have a chance to release a fix. Responsible disclosure through private channels gives us time to patch the issue and protect all users.

Instead, please send an email to **engineering@trustbound.ai** with the following information:

- A description of the vulnerability
- Steps to reproduce the issue
- Potential impact of the vulnerability
- Any suggested fixes (if you have them)

### What to Expect

- **Acknowledgment**: We will acknowledge receipt of your vulnerability report within 48 hours.
- **Communication**: We will keep you informed about our progress toward fixing the vulnerability.
- **Resolution**: We aim to resolve critical vulnerabilities within 7 days and will release a patch as soon as possible.
- **Disclosure**: After a fix is released, we will publicly disclose the vulnerability details in our release notes and changelog. We believe in transparency and want the community to understand what was fixed.
- **Credit**: We will credit you in our release notes (unless you prefer to remain anonymous).

### Safe Harbor

We consider security research conducted in accordance with this policy to be:

- Authorized concerning any applicable anti-hacking laws
- Authorized concerning any relevant anti-circumvention laws
- Exempt from restrictions in our terms of service that would interfere with conducting security research

We will not pursue civil action or initiate a complaint with law enforcement for accidental, good-faith violations of this policy.

## Security Best Practices

When using Dream Test in your projects:

1. **Keep dependencies updated**: Regularly update to the latest version to receive security patches.
2. **Review test code**: Even in test environments, be mindful of what external resources tests may access.
3. **Sandbox appropriately**: Use Dream Test's sandbox features when testing code that interacts with external systems.

## Contact

For any security-related questions or concerns, please contact us at **engineering@trustbound.ai**.
