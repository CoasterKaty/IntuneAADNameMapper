# Trigger-DeviceCertUpdate
Katy Nicholson, 2024-08-30

When using Azure AD Joined devices, Intune Certificate Connector, on-premises AD CA and device based certificates with NPS authentication, you will need the thumbprint of any certificates issued to the device to be present on an on-premises AD computer object.

Not included in this script is creating the on-prem AD computer objects for all Azure AD joined Autopilot devices.

This script is designed to be run by scheduled task on security log event ID 4887 (Certificate Request: Success) and will add the thumbprint to the computer object. I find this much better than an hourly scheduled full sync as there is significantly less risk of a device being left with no connectivity for up to an hour. 

Details on use are available in my [blog post](https://katystech.blog/mem/namemapping-aadd-event-task).
