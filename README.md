# Jitsi Cluster

![Jitsi Cluster](/docs/images/jitsi-cluster.png)

`LXC` based `Jitsi` cluster on `Debian 12 Bookworm`.

## Installation

See [the deployment guide](/INSTALL.md).

## Why

Deploying a `Jitsi` cluster is a complex task and requires a lot of specific
configurations on each component to function properly. This repository contains
tools that simplify the deployment processes and automatically configure each
component without any user interaction.

## Features

- `JMS` node is the core of the cluster.

- Allow to add as many `JVBs` as needed to scale up the number of participants
  and meetings.

- Allow to add as many `Jibris` as needed to increase the number of concurrent
  recordings.

- Allow to add as many `sip-jibri` as needed to allow video-SIP participants.

- Built-in `component-selector` to manage `jibri` and `sip-jibri` nodes
  programmatically. See
  [component-selector-api-examples](/docs/component-selector-api-examples)
  folder for more details.

- Built-in `dial-plan` service to provide `SIP` contact list for `Jitsi` UI.

- `JWT` authentication and `guest` domain are enabled and configured by default.

- `Whiteboard` (_based on Excalidraw_) is enabled and configured by default.

## Sponsors

[![Nordeck](/docs/images/nordeck.png)](https://nordeck.net/)
