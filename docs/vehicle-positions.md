### Vehicle positions

#### Overview

The vehicle positions are sent to Digitransit through a chain of services which are drawn in the following
diagram:

![vehicle positions diagram](vehicle-positions.png)

Originally, the data is provided by VVS and picked up by a GTFS-RT-to-MQTT bridge. This then
publishes the data onto a MQTT broker (Mosquitto) which makes them available through a series
of topics.

Digitransit can connect to the MQTT broker via Websockets and subscribes to the data. Depending
on the exact poll frequency, it may take a few seconds until data really appears in the app.

If you want to look at the raw MQTT topic you can do the following:

```sh
npm install -g mqtt
mqtt subscribe -h vehiclepositions.stadtnavi.eu -p 443 -l wss -v -t "#" -i my-client
```

#### Ansible

The code for the vehicle positions is in the `leonardehrenfried/baseline` repository: https://github.com/leonardehrenfried/ansible-baseline/tree/main/roles/vehicle_positions

#### Configuration

The following ansible configuration variables are available:

- `vehicle_positions_poll_interval`: how often the source GTFS-RT feeds is polled, in seconds (default: 5)

#### Ports

Generally, the only port that is really necessary is 443 as this is the one to which Digitransit
connects to open the secure websocket connection. (It's very common to run the MQTT over the websocket
protocol.)

However, if you want to use the native MQTT protocol, you can also connect using port 1883. In order
to do this you need to open the port on the server first, which is done with the ansible configuration 
variable `firewall_allowed_tcp_ports`.
