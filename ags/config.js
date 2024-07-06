// const hyprland = await Service.import("hyprland")
//const notifications = await Service.import("notifications")
const mpris = await Service.import("mpris")
const audio = await Service.import("audio")
const battery = await Service.import("battery")
const systemtray = await Service.import("systemtray")

const date = Variable({hours: "", minutes: "", ampm: ""}, {
    poll: [1000, 'date +"%I %M %p"', (dateString) => {
        const splitDate = dateString.split(" ")
        return {
            hours: splitDate[0],
            minutes: splitDate[1],
            ampm: splitDate[2],
        }
    }],
})

// widgets can be only assigned as a child in one container
// so to make a reuseable widget, make it a function
// then you can simply instantiate one by calling it

// function Workspaces() {
//     const activeId = hyprland.active.workspace.bind("id")
//     const workspaces = hyprland.bind("workspaces")
//         .as(ws => ws.map(({ id }) => Widget.Button({
//             on_clicked: () => hyprland.messageAsync(`dispatch workspace ${id}`),
//             child: Widget.Label(`${id}`),
//             class_name: activeId.as(i => `${i === id ? "focused" : ""}`),
//         })))

//     return Widget.Box({
//         class_name: "workspaces",
//         children: workspaces,
//     })
// }


function ClientTitle() {
    return Widget.Label({
        class_name: "client-title",
        label: "hello"
        // label: hyprland.active.client.bind("title"),
    })
}


function Clock() {
    const dateSplit = date.bind().transformFn(date => ({
        hours: date.split(" ")[0],
        minutes: date.split(" ")[1],
        ampm: date.split(" ")[2],
    }));
    return Widget.Box({
        class_name: "clock",
        vertical: true,
        children: [
            Widget.Label({
                class_name: "clock",
                label: date.bind().as(date => date['hours']),
            }),
            Widget.Label({
                class_name: "clock",
                label: date.bind().as(date => date['minutes']),
            }),
            Widget.Label({
                class_name: "clock",
                label: date.bind().as(date => date['ampm']),
            }),
        ],
    
    }) 
}


// we don't need dunst or any other notification daemon
// because the Notifications module is a notification daemon itsel

function Media() {
    const label = Utils.watch("", mpris, "player-changed", () => {
        if (mpris.players[0]) {
            const { track_artists, track_title } = mpris.players[0]
            return `${track_artists.join(", ")} - ${track_title}`
        } else {
            return "Nothing is playing"
        }
    })

    return Widget.Button({
        class_name: "media",
        widthRequest: 20,
        vexpand: true,
        on_primary_click: () => mpris.getPlayer("")?.playPause(),
        on_scroll_up: () => mpris.getPlayer("")?.next(),
        on_scroll_down: () => mpris.getPlayer("")?.previous(),
        child: Widget.Label({  vexpand: true}),
    })
}


function Volume() {
    const icons = {
        101: "overamplified",
        67: "high",
        34: "medium",
        1: "low",
        0: "muted",
    }

    function getIcon() {
        const icon = audio.speaker.is_muted ? 0 : [101, 67, 34, 1, 0].find(
            threshold => threshold <= audio.speaker.volume * 100)

        return `audio-volume-${icons[icon]}-symbolic`
    }

    const icon = Widget.Icon({
        icon: Utils.watch(getIcon(), audio.speaker, getIcon),
    })

    const slider = Widget.Slider({
        draw_value: false,
        vertical: true,
        heightRequest: 140,
        on_change: ({ value }) => audio.speaker.volume = value,
        setup: self => self.hook(audio.speaker, () => {
            self.value = audio.speaker.volume || 0
        }),
    })

    return Widget.Box({
        class_name: "volume",
        vertical: true,
        children: [icon, slider],
    })
}


function BatteryLabel() {
    const value = battery.bind("percent").as(p => p > 0 ? p / 100 : 0)
    const icon = battery.bind("percent").as(p =>
        `battery-level-${Math.floor(p / 10) * 10}-symbolic`)

    return Widget.Box({
        class_name: "battery",
        vertical: true,
        visible: battery.bind("available"),
        children: [
            Widget.Icon({ icon }),
            Widget.LevelBar({
                widthRequest: 20,
                heightRequest: 140,
                hpack: "center",
                vertical: true,
                value,
            }),
        ],
    })
}


function SysTray() {
    const items = systemtray.bind("items")
        .as(items => items.map(item => Widget.Button({
            child: Widget.Icon({ icon: item.bind("icon") }),
            on_primary_click: (_, event) => item.activate(event),
            on_secondary_click: (_, event) => item.openMenu(event),
            tooltip_markup: item.bind("tooltip_markup"),
        })))

    return Widget.Box({
        vertical: true,
        children: items,
    })
}


// layout of the bar
function Left() {
    return Widget.Box({
        vertical: true,
        vpack: "start",
        spacing: 8,    
        class_name: "left",
        children: [
            // Workspaces(),
            // ClientTitle(),
        ],
    })
}

function Center() {
    return Widget.Box({
        class_name: "center",
        vpack: "center",
        vertical: true,
        vexpand: true,
        spacing: 8,
        children: [
            // Media(),
        ],
    })
}

function Right() {
    return Widget.Box({
        vpack: "end",
        vertical: true,
        class_name: "right",
        spacing: 8,
        children: [
            Volume(),
            BatteryLabel(),
            Clock(),
            SysTray(),
        ],
    })
}

function Bar(monitor = 0) {
    return Widget.Window({
        name: `bar-${monitor}`, // name has to be unique
        class_name: "bar",
        monitor,
        layer: "top",
        anchor: ["left", "top", "bottom"],
        exclusivity: "exclusive",
        child: Widget.CenterBox({
            vertical: true,
            start_widget: Left(),
            center_widget: Center(),
            end_widget: Right(),
        }),
    })
}

App.config({
    style: "./style.css",
    windows: [
        Bar(),
        // you can call it, for each monitor
        // Bar(0),
        // Bar(1)
    ],
})

export { }
