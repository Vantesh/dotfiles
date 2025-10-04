pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

Singleton {
    id: root

    readonly property var facts: [
        "A photon takes 100,000 to 200,000 years bouncing through the Sun's dense core, then races to Earth in just 8 minutes 20 seconds.",
        "A teaspoon of neutron star matter would weigh a billion metric tons here on Earth.",
        "Right now, 100 trillion solar neutrinos are passing through your body every second.",
        "The Sun converts 4 million metric tons of matter into pure energy every second—enough to power Earth for 500,000 years.",
        "The universe still glows with leftover heat from the Big Bang—just 2.7 degrees above absolute zero.",
        "There's a nebula out there that's actually colder than empty space itself.",
        "We've detected black holes crashing together by measuring spacetime stretch by less than 1/10,000th the width of a proton.",
        "Fast radio bursts can release more energy in 5 milliseconds than our Sun produces in 3 days.",
        "Our galaxy might be crawling with billions of rogue planets drifting alone in the dark.",
        "Distant galaxies can move away from us faster than light because space itself is stretching.",
        "The edge of what we can see is 46.5 billion light-years away, even though the universe is only 13.8 billion years old.",
        "The universe is mostly invisible: 5% regular matter, 27% dark matter, 68% dark energy.",
        "A day on Venus lasts longer than its entire year around the Sun.",
        "On Mercury, the time between sunrises is 176 Earth days long.",
        "In about 4.5 billion years, our galaxy will smash into Andromeda.",
        "Most of the gold in your jewelry was forged when neutron stars collided somewhere in space.",
        "PSR J1748-2446ad, the fastest spinning star, rotates 716 times per second—its equator moves at 24% the speed of light.",
        "Cosmic rays create particles that shouldn't make it to Earth's surface, but time dilation lets them sneak through.",
        "Jupiter's magnetic field is so huge that if we could see it, it would look bigger than the Moon in our sky.",
        "Interstellar space is so empty it's like a cube 32 kilometers wide containing just a single grain of sand.",
        "Voyager 1 is 24 billion kilometers away but won't leave the Sun's gravitational influence for another 30,000 years.",
        "Counting to a billion at one number per second would take over 31 years.",
        "Space is so vast, even speeding at light-speed, you'd never return past the cosmic horizon.",
        "Astronauts on the ISS age about 0.01 seconds less each year than people on Earth.",
        "Sagittarius B2, a dust cloud near our galaxy's center, contains ethyl formate—the compound that gives raspberries their flavor and rum its smell.",
        "Beyond 16 billion light-years, the cosmic event horizon marks where space expands too fast for light to ever reach us again.",
        "Even at light-speed, you'd never catch up to most galaxies—space expands faster.",
        "Only around 5% of galaxies are ever reachable—even at light-speed.",
        "If the Sun vanished, we'd still orbit it for 8 minutes before drifting away.",
        "If a planet 65 million light-years away looked at Earth now, it'd see dinosaurs.",
        "Our oldest radio signals will reach the Milky Way's center in 26,000 years.",
        "Every atom in your body heavier than hydrogen was forged in the nuclear furnace of a dying star.",
        "The Moon moves 3.8 centimeters farther from Earth every year.",
        "The universe creates 275 million new stars every single day.",
        "Jupiter's Great Red Spot is a storm twice the size of Earth that has been raging for at least 350 years.",
        "If you watched someone fall into a black hole, they'd appear frozen at the event horizon forever—time effectively stops from your perspective.",
        "The Boötes Supervoid is a cosmic desert 1.8 billion light-years across with 60% fewer galaxies than it should have."
    ]

    function getRandomFact() {
        return facts[Math.floor(Math.random() * facts.length)]
    }
}
