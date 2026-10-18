import QtQuick
import Quickshell.Io
import qs.Commons as Commons

// The plugin's strings from i18n/<code>.json, falling back to the base
// language (es-MX to es) and then English. It follows the catalog format of
// Commons.Translations, but `language` can be pinned in the widget settings
// instead of always following Omarchy's language ("auto").
QtObject {
  id: root

  property string language: "auto"

  readonly property string code: language && language !== "auto" ? language : Commons.I18n.language
  readonly property string base: code.split("-")[0]
  readonly property string directory: String(Qt.resolvedUrl("i18n")).replace(/^file:\/\//, "")

  // Native names for the language picker; "auto" follows Omarchy.
  readonly property var languages: [
    { value: "en", label: "English" },
    { value: "tr", label: "Türkçe" },
    { value: "de", label: "Deutsch" },
    { value: "es", label: "Español" },
    { value: "fr", label: "Français" },
    { value: "it", label: "Italiano" },
    { value: "ru", label: "Русский" },
    { value: "hi", label: "हिन्दी" }
  ]

  property var english: ({})
  property var baseStrings: ({})
  property var exact: ({})

  function parse(raw) {
    try {
      var parsed = JSON.parse(raw || "{}")
      return parsed && typeof parsed === "object" && !Array.isArray(parsed) ? parsed : ({})
    } catch (e) {
      return ({})
    }
  }

  // CLDR categories for the shipped languages, whole numbers only. French
  // and Hindi count 0 and 1 as "one"; Russian has one/few/many; the rest use
  // "one" for exactly 1. A missing form falls back to "other".
  function category(n) {
    if (base === "fr" || base === "hi") return n === 0 || n === 1 ? "one" : "other"
    if (base === "ru") {
      var d = n % 10, h = n % 100
      if (d === 1 && h !== 11) return "one"
      if (d >= 2 && d <= 4 && (h < 12 || h > 14)) return "few"
      return "many"
    }
    return n === 1 ? "one" : "other"
  }

  function lookup(key) {
    if (exact[key] !== undefined) return exact[key]
    if (baseStrings[key] !== undefined) return baseStrings[key]
    return english[key]
  }

  function t(key) {
    var value = lookup(key)
    if (value && typeof value === "object") value = value.other
    return typeof value === "string" && value.length > 0 ? value : key
  }

  function tn(key, n) {
    var value = lookup(key)
    if (value && typeof value === "object") value = value[category(n)] || value.other
    return typeof value === "string" && value.length > 0 ? value : key
  }

  property FileView englishFile: FileView {
    path: root.directory + "/en.json"
    printErrors: false
    onLoaded: root.english = root.parse(text())
  }

  property FileView baseFile: FileView {
    path: root.base !== "en" ? root.directory + "/" + root.base + ".json" : ""
    printErrors: false
    onLoaded: root.baseStrings = root.parse(text())
    onLoadFailed: root.baseStrings = ({})
    onPathChanged: if (!path) root.baseStrings = ({})
  }

  property FileView exactFile: FileView {
    path: root.code !== root.base ? root.directory + "/" + root.code + ".json" : ""
    printErrors: false
    onLoaded: root.exact = root.parse(text())
    onLoadFailed: root.exact = ({})
    onPathChanged: if (!path) root.exact = ({})
  }
}
