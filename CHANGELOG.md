# Changelog

## 0.2.0

Adds **conversion tracking** for deep-link attribution: `trackLead` (3 types —
direct / anonymous / attributed), `trackSale` (2 types — direct / attributed), and
`identify`. A deep-link match persists `Li2.lastClickId` (30-day TTL) and the
attributed methods auto-read it, so a lead/sale ties back to the click with no
manual plumbing.

No changes to the deep-link API.

## 0.1.0

Initial release. Deep-link resolution: immediate Universal Links plus
clipboard-based deferred attribution with a privacy-first consent tap.
`Li2.configure`, `Li2DeepLinkResolver`, `Li2PasteButton`, `li2DeepLink` modifier,
`Li2.lastClickId`.
