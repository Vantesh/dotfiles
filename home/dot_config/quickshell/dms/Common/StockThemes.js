// Stock theme definitions for DankMaterialShell
// Separated from Theme.qml to keep that file clean

const CatppuccinMocha = {
    surface: "#45475a",
    surfaceText: "#cdd6f4",
    surfaceVariant: "#45475a",
    surfaceVariantText: "#a6adc8",
    background: "#1e1e2e",
    backgroundText: "#cdd6f4",
    outline: "#6c7086",
    surfaceContainer: "#313244",
    surfaceContainerHigh: "#585b70"
}

const CatppuccinLatte = {
    surface: "#bcc0cc",
    surfaceText: "#4c4f69",
    surfaceVariant: "#bcc0cc",
    surfaceVariantText: "#6c6f85",
    background: "#eff1f5",
    backgroundText: "#4c4f69",
    outline: "#9ca0b0",
    surfaceContainer: "#ccd0da",
    surfaceContainerHigh: "#acb0be"
}

const CatppuccinVariants = {
    "cat-rosewater": {
        name: "Rosewater",
        dark: { primary: "#f5e0dc", secondary: "#f2cdcd", primaryText: "#1e1e2e", primaryContainer: "#8b6b5e", surfaceTint: "#f5e0dc" },
        light: { primary: "#dc8a78", secondary: "#dd7878", primaryText: "#ffffff", primaryContainer: "#f4d2ca", surfaceTint: "#dc8a78" }
    },
    "cat-flamingo": {
        name: "Flamingo",
        dark: { primary: "#f2cdcd", secondary: "#f5e0dc", primaryText: "#1e1e2e", primaryContainer: "#885d62", surfaceTint: "#f2cdcd" },
        light: { primary: "#dd7878", secondary: "#dc8a78", primaryText: "#ffffff", primaryContainer: "#f4caca", surfaceTint: "#dd7878" }
    },
    "cat-pink": {
        name: "Pink",
        dark: { primary: "#f5c2e7", secondary: "#cba6f7", primaryText: "#1e1e2e", primaryContainer: "#8b537a", surfaceTint: "#f5c2e7" },
        light: { primary: "#ea76cb", secondary: "#8839ef", primaryText: "#ffffff", primaryContainer: "#f7c9e7", surfaceTint: "#ea76cb" }
    },
    "cat-mauve": {
        name: "Mauve",
        dark: { primary: "#cba6f7", secondary: "#b4befe", primaryText: "#1e1e2e", primaryContainer: "#61378a", surfaceTint: "#cba6f7" },
        light: { primary: "#8839ef", secondary: "#7287fd", primaryText: "#ffffff", primaryContainer: "#e4d3ff", surfaceTint: "#8839ef" }
    },
    "cat-red": {
        name: "Red",
        dark: { primary: "#f38ba8", secondary: "#eba0ac", primaryText: "#1e1e2e", primaryContainer: "#891c3b", surfaceTint: "#f38ba8" },
        light: { primary: "#d20f39", secondary: "#e64553", primaryText: "#ffffff", primaryContainer: "#f1b8c4", surfaceTint: "#d20f39" }
    },
    "cat-maroon": {
        name: "Maroon",
        dark: { primary: "#eba0ac", secondary: "#f38ba8", primaryText: "#1e1e2e", primaryContainer: "#81313f", surfaceTint: "#eba0ac" },
        light: { primary: "#e64553", secondary: "#d20f39", primaryText: "#ffffff", primaryContainer: "#f4c3c8", surfaceTint: "#e64553" }
    },
    "cat-peach": {
        name: "Peach",
        dark: { primary: "#fab387", secondary: "#f9e2af", primaryText: "#1e1e2e", primaryContainer: "#90441a", surfaceTint: "#fab387" },
        light: { primary: "#fe640b", secondary: "#df8e1d", primaryText: "#ffffff", primaryContainer: "#ffddcc", surfaceTint: "#fe640b" }
    },
    "cat-yellow": {
        name: "Yellow",
        dark: { primary: "#f9e2af", secondary: "#a6e3a1", primaryText: "#1e1e2e", primaryContainer: "#8f7342", surfaceTint: "#f9e2af" },
        light: { primary: "#df8e1d", secondary: "#40a02b", primaryText: "#ffffff", primaryContainer: "#fff3cc", surfaceTint: "#df8e1d" }
    },
    "cat-green": {
        name: "Green",
        dark: { primary: "#a6e3a1", secondary: "#94e2d5", primaryText: "#1e1e2e", primaryContainer: "#3c7534", surfaceTint: "#a6e3a1" },
        light: { primary: "#40a02b", secondary: "#179299", primaryText: "#ffffff", primaryContainer: "#d4f5d4", surfaceTint: "#40a02b" }
    },
    "cat-teal": {
        name: "Teal",
        dark: { primary: "#94e2d5", secondary: "#89dceb", primaryText: "#1e1e2e", primaryContainer: "#2a7468", surfaceTint: "#94e2d5" },
        light: { primary: "#179299", secondary: "#04a5e5", primaryText: "#ffffff", primaryContainer: "#ccf2f2", surfaceTint: "#179299" }
    },
    "cat-sky": {
        name: "Sky",
        dark: { primary: "#89dceb", secondary: "#74c7ec", primaryText: "#1e1e2e", primaryContainer: "#196e7e", surfaceTint: "#89dceb" },
        light: { primary: "#04a5e5", secondary: "#209fb5", primaryText: "#ffffff", primaryContainer: "#ccebff", surfaceTint: "#04a5e5" }
    },
    "cat-sapphire": {
        name: "Sapphire",
        dark: { primary: "#74c7ec", secondary: "#89b4fa", primaryText: "#1e1e2e", primaryContainer: "#0a597f", surfaceTint: "#74c7ec" },
        light: { primary: "#209fb5", secondary: "#1e66f5", primaryText: "#ffffff", primaryContainer: "#d0f0f5", surfaceTint: "#209fb5" }
    },
    "cat-blue": {
        name: "Blue",
        dark: { primary: "#89b4fa", secondary: "#b4befe", primaryText: "#1e1e2e", primaryContainer: "#19468d", surfaceTint: "#89b4fa" },
        light: { primary: "#1e66f5", secondary: "#7287fd", primaryText: "#ffffff", primaryContainer: "#ccd9ff", surfaceTint: "#1e66f5" }
    },
    "cat-lavender": {
        name: "Lavender",
        dark: { primary: "#b4befe", secondary: "#cba6f7", primaryText: "#1e1e2e", primaryContainer: "#4a5091", surfaceTint: "#b4befe" },
        light: { primary: "#7287fd", secondary: "#8839ef", primaryText: "#ffffff", primaryContainer: "#dde1ff", surfaceTint: "#7287fd" }
    }
}

function getCatppuccinTheme(variant, isLight = false) {
    const variantData = CatppuccinVariants[variant]
    if (!variantData) return null

    const baseColors = isLight ? CatppuccinLatte : CatppuccinMocha
    const accentColors = isLight ? variantData.light : variantData.dark

    return Object.assign({
        name: `${variantData.name}${isLight ? ' Light' : ''}`
    }, baseColors, accentColors)
}

const StockThemes = {
    DARK: {
        blue: {
            name: "Blue",
            primary: "#42a5f5",
            primaryText: "#000000",
            primaryContainer: "#1976d2",
            secondary: "#8ab4f8",
            surface: "#1a1c1e",
            surfaceText: "#e3e8ef",
            surfaceVariant: "#44464f",
            surfaceVariantText: "#c4c7c5",
            surfaceTint: "#8ab4f8",
            background: "#1a1c1e",
            backgroundText: "#e3e8ef",
            outline: "#8e918f",
            surfaceContainer: "#1e2023",
            surfaceContainerHigh: "#292b2f"
        },
        deepBlue: {
            name: "Deep Blue",
            primary: "#0061a4",
            primaryText: "#000000",
            primaryContainer: "#004881",
            secondary: "#42a5f5",
            surface: "#1a1c1e",
            surfaceText: "#e3e8ef",
            surfaceVariant: "#44464f",
            surfaceVariantText: "#c4c7c5",
            surfaceTint: "#8ab4f8",
            background: "#1a1c1e",
            backgroundText: "#e3e8ef",
            outline: "#8e918f",
            surfaceContainer: "#1e2023",
            surfaceContainerHigh: "#292b2f"
        },
        purple: {
            name: "Purple",
            primary: "#D0BCFF",
            primaryText: "#381E72",
            primaryContainer: "#4F378B",
            secondary: "#CCC2DC",
            surface: "#10121E",
            surfaceText: "#E6E0E9",
            surfaceVariant: "#49454F",
            surfaceVariantText: "#CAC4D0",
            surfaceTint: "#D0BCFF",
            background: "#10121E",
            backgroundText: "#E6E0E9",
            outline: "#938F99",
            surfaceContainer: "#1D1B20",
            surfaceContainerHigh: "#2B2930"
        },
        green: {
            name: "Green",
            primary: "#4caf50",
            primaryText: "#000000",
            primaryContainer: "#388e3c",
            secondary: "#81c995",
            surface: "#0f1411",
            surfaceText: "#e1f5e3",
            surfaceVariant: "#404943",
            surfaceVariantText: "#c1cbc4",
            surfaceTint: "#81c995",
            background: "#0f1411",
            backgroundText: "#e1f5e3",
            outline: "#8b938c",
            surfaceContainer: "#1a1f1b",
            surfaceContainerHigh: "#252a26"
        },
        orange: {
            name: "Orange",
            primary: "#ff6d00",
            primaryText: "#000000",
            primaryContainer: "#e65100",
            secondary: "#ffb74d",
            surface: "#1c1410",
            surfaceText: "#f5f1ea",
            surfaceVariant: "#4a453a",
            surfaceVariantText: "#cbc5b8",
            surfaceTint: "#ffb74d",
            background: "#1c1410",
            backgroundText: "#f5f1ea",
            outline: "#958f84",
            surfaceContainer: "#211e17",
            surfaceContainerHigh: "#2c291f"
        },
        red: {
            name: "Red",
            primary: "#f44336",
            primaryText: "#000000",
            primaryContainer: "#d32f2f",
            secondary: "#f28b82",
            surface: "#1c1011",
            surfaceText: "#f5e8ea",
            surfaceVariant: "#4a3f41",
            surfaceVariantText: "#cbc2c4",
            surfaceTint: "#f28b82",
            background: "#1c1011",
            backgroundText: "#f5e8ea",
            outline: "#958b8d",
            surfaceContainer: "#211b1c",
            surfaceContainerHigh: "#2c2426"
        },
        cyan: {
            name: "Cyan",
            primary: "#00bcd4",
            primaryText: "#000000",
            primaryContainer: "#0097a7",
            secondary: "#4dd0e1",
            surface: "#0f1617",
            surfaceText: "#e8f4f5",
            surfaceVariant: "#3f474a",
            surfaceVariantText: "#c2c9cb",
            surfaceTint: "#4dd0e1",
            background: "#0f1617",
            backgroundText: "#e8f4f5",
            outline: "#8c9194",
            surfaceContainer: "#1a1f20",
            surfaceContainerHigh: "#252b2c"
        },
        pink: {
            name: "Pink",
            primary: "#e91e63",
            primaryText: "#000000",
            primaryContainer: "#c2185b",
            secondary: "#f8bbd9",
            surface: "#1a1014",
            surfaceText: "#f3e8ee",
            surfaceVariant: "#483f45",
            surfaceVariantText: "#c9c2c7",
            surfaceTint: "#f8bbd9",
            background: "#1a1014",
            backgroundText: "#f3e8ee",
            outline: "#938a90",
            surfaceContainer: "#1f1b1e",
            surfaceContainerHigh: "#2a2428"
        },
        amber: {
            name: "Amber",
            primary: "#ffc107",
            primaryText: "#000000",
            primaryContainer: "#ff8f00",
            secondary: "#ffd54f",
            surface: "#1a1710",
            surfaceText: "#f3f0e8",
            surfaceVariant: "#49453a",
            surfaceVariantText: "#cac5b8",
            surfaceTint: "#ffd54f",
            background: "#1a1710",
            backgroundText: "#f3f0e8",
            outline: "#949084",
            surfaceContainer: "#1f1e17",
            surfaceContainerHigh: "#2a281f"
        },
        coral: {
            name: "Coral",
            primary: "#ffb4ab",
            primaryText: "#000000",
            primaryContainer: "#8c1d18",
            secondary: "#f9dedc",
            surface: "#1a1110",
            surfaceText: "#f1e8e7",
            surfaceVariant: "#4a4142",
            surfaceVariantText: "#cdc2c1",
            surfaceTint: "#ffb4ab",
            background: "#1a1110",
            backgroundText: "#f1e8e7",
            outline: "#968b8a",
            surfaceContainer: "#201a19",
            surfaceContainerHigh: "#2b2221"
        }
    },
    LIGHT: {
        blue: {
            name: "Blue Light",
            primary: "#1976d2",
            primaryText: "#ffffff",
            primaryContainer: "#e3f2fd",
            secondary: "#42a5f5",
            surface: "#fefefe",
            surfaceText: "#1a1c1e",
            surfaceVariant: "#e7e0ec",
            surfaceVariantText: "#49454f",
            surfaceTint: "#1976d2",
            background: "#fefefe",
            backgroundText: "#1a1c1e",
            outline: "#79747e",
            surfaceContainer: "#f3f3f3",
            surfaceContainerHigh: "#ececec"
        },
        deepBlue: {
            name: "Deep Blue Light",
            primary: "#0061a4",
            primaryText: "#ffffff",
            primaryContainer: "#cfe5ff",
            secondary: "#1976d2",
            surface: "#fefefe",
            surfaceText: "#1a1c1e",
            surfaceVariant: "#e7e0ec",
            surfaceVariantText: "#49454f",
            surfaceTint: "#0061a4",
            background: "#fefefe",
            backgroundText: "#1a1c1e",
            outline: "#79747e",
            surfaceContainer: "#f3f3f3",
            surfaceContainerHigh: "#ececec"
        },
        purple: {
            name: "Purple Light",
            primary: "#6750A4",
            primaryText: "#ffffff",
            primaryContainer: "#EADDFF",
            secondary: "#625B71",
            surface: "#FFFBFE",
            surfaceText: "#1C1B1F",
            surfaceVariant: "#E7E0EC",
            surfaceVariantText: "#49454F",
            surfaceTint: "#6750A4",
            background: "#FFFBFE",
            backgroundText: "#1C1B1F",
            outline: "#79747E",
            surfaceContainer: "#F3EDF7",
            surfaceContainerHigh: "#ECE6F0"
        },
        green: {
            name: "Green Light",
            primary: "#2e7d32",
            primaryText: "#ffffff",
            primaryContainer: "#e8f5e8",
            secondary: "#4caf50",
            surface: "#fefefe",
            surfaceText: "#1a1c1e",
            surfaceVariant: "#e7e0ec",
            surfaceVariantText: "#49454f",
            surfaceTint: "#2e7d32",
            background: "#fefefe",
            backgroundText: "#1a1c1e",
            outline: "#79747e",
            surfaceContainer: "#f3f3f3",
            surfaceContainerHigh: "#ececec"
        },
        orange: {
            name: "Orange Light",
            primary: "#e65100",
            primaryText: "#ffffff",
            primaryContainer: "#ffecb3",
            secondary: "#ff9800",
            surface: "#fefefe",
            surfaceText: "#1a1c1e",
            surfaceVariant: "#e7e0ec",
            surfaceVariantText: "#49454f",
            surfaceTint: "#e65100",
            background: "#fefefe",
            backgroundText: "#1a1c1e",
            outline: "#79747e",
            surfaceContainer: "#f3f3f3",
            surfaceContainerHigh: "#ececec"
        },
        red: {
            name: "Red Light",
            primary: "#d32f2f",
            primaryText: "#ffffff",
            primaryContainer: "#ffebee",
            secondary: "#f44336",
            surface: "#fefefe",
            surfaceText: "#1a1c1e",
            surfaceVariant: "#e7e0ec",
            surfaceVariantText: "#49454f",
            surfaceTint: "#d32f2f",
            background: "#fefefe",
            backgroundText: "#1a1c1e",
            outline: "#79747e",
            surfaceContainer: "#f3f3f3",
            surfaceContainerHigh: "#ececec"
        },
        cyan: {
            name: "Cyan Light",
            primary: "#0097a7",
            primaryText: "#ffffff",
            primaryContainer: "#e0f2f1",
            secondary: "#00bcd4",
            surface: "#fefefe",
            surfaceText: "#1a1c1e",
            surfaceVariant: "#e7e0ec",
            surfaceVariantText: "#49454f",
            surfaceTint: "#0097a7",
            background: "#fefefe",
            backgroundText: "#1a1c1e",
            outline: "#79747e",
            surfaceContainer: "#f3f3f3",
            surfaceContainerHigh: "#ececec"
        },
        pink: {
            name: "Pink Light",
            primary: "#c2185b",
            primaryText: "#ffffff",
            primaryContainer: "#fce4ec",
            secondary: "#e91e63",
            surface: "#fefefe",
            surfaceText: "#1a1c1e",
            surfaceVariant: "#e7e0ec",
            surfaceVariantText: "#49454f",
            surfaceTint: "#c2185b",
            background: "#fefefe",
            backgroundText: "#1a1c1e",
            outline: "#79747e",
            surfaceContainer: "#f3f3f3",
            surfaceContainerHigh: "#ececec"
        },
        amber: {
            name: "Amber Light",
            primary: "#ff8f00",
            primaryText: "#000000",
            primaryContainer: "#fff8e1",
            secondary: "#ffc107",
            surface: "#fefefe",
            surfaceText: "#1a1c1e",
            surfaceVariant: "#e7e0ec",
            surfaceVariantText: "#49454f",
            surfaceTint: "#ff8f00",
            background: "#fefefe",
            backgroundText: "#1a1c1e",
            outline: "#79747e",
            surfaceContainer: "#f3f3f3",
            surfaceContainerHigh: "#ececec"
        },
        coral: {
            name: "Coral Light",
            primary: "#8c1d18",
            primaryText: "#ffffff",
            primaryContainer: "#ffdad6",
            secondary: "#ff5449",
            surface: "#fefefe",
            surfaceText: "#1a1c1e",
            surfaceVariant: "#e7e0ec",
            surfaceVariantText: "#49454f",
            surfaceTint: "#8c1d18",
            background: "#fefefe",
            backgroundText: "#1a1c1e",
            outline: "#79747e",
            surfaceContainer: "#f3f3f3",
            surfaceContainerHigh: "#ececec"
        }
    }
}

const ThemeCategories = {
    GENERIC: {
        name: "Generic",
        variants: ["blue", "deepBlue", "purple", "green", "orange", "red", "cyan", "pink", "amber", "coral"]
    },
    CATPPUCCIN: {
        name: "Catppuccin",
        variants: Object.keys(CatppuccinVariants)
    }
}

const ThemeNames = {
    BLUE: "blue",
    DEEP_BLUE: "deepBlue",
    PURPLE: "purple",
    GREEN: "green",
    ORANGE: "orange",
    RED: "red",
    CYAN: "cyan",
    PINK: "pink",
    AMBER: "amber",
    CORAL: "coral",
    DYNAMIC: "dynamic"
}

function isStockTheme(themeName) {
    return Object.keys(StockThemes.DARK).includes(themeName)
}

function isCatppuccinVariant(themeName) {
    return Object.keys(CatppuccinVariants).includes(themeName)
}

function getAvailableThemes(isLight = false) {
    return isLight ? StockThemes.LIGHT : StockThemes.DARK
}

function getThemeByName(themeName, isLight = false) {
    if (isCatppuccinVariant(themeName)) {
        return getCatppuccinTheme(themeName, isLight)
    }
    const themes = getAvailableThemes(isLight)
    return themes[themeName] || themes.blue
}

function getAllThemeNames() {
    return Object.keys(StockThemes.DARK)
}

function getCatppuccinVariantNames() {
    return Object.keys(CatppuccinVariants)
}

function getThemeCategories() {
    return ThemeCategories
}