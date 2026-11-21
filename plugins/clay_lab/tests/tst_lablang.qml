// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// The language lookup and the number format a lab is read in (#532): German
// falls back to English and then to the key, and a German reading has a
// decimal comma.

import QtQuick
import QtTest
import Clayground.Lab

Item {
    width: 50; height: 50

    TestCase {
        name: "LabLang"

        function initTestCase() {
            LabLang.register({
                "en": { "tst.both": "both", "tst.enOnly": "english only",
                        "tst.args": "%1 of %2" },
                "de": { "tst.both": "beide", "tst.args": "%1 von %2" }
            })
        }

        function cleanup() { LabLang.lang = "en" }

        function test_languagesOfferedEnglishFirst() {
            compare(LabLang.languages[0], "en")
            verify(LabLang.languages.indexOf("de") !== -1)
        }

        function test_lookupInTheActiveLanguage() {
            compare(LabLang.t("tst.both"), "both")
            LabLang.lang = "de"
            compare(LabLang.t("tst.both"), "beide")
        }

        function test_germanFallsBackToEnglish() {
            LabLang.lang = "de"
            compare(LabLang.t("tst.enOnly"), "english only")
        }

        function test_missingEverywhereShowsTheKey() {
            LabLang.lang = "de"
            compare(LabLang.t("tst.nowhere"), "tst.nowhere")
        }

        function test_kernelChromeIsTranslated() {
            LabLang.lang = "de"
            compare(LabLang.t("time.pause"), "Pause")
            LabLang.lang = "en"
            compare(LabLang.t("time.pause"), "pause")
        }

        // a lab's own wording wins over the kernel's, whatever the order
        function test_labOverridesKernel() {
            LabLang.register({ "en": { "time.resume": "go on" } })
            compare(LabLang.t("time.resume"), "go on")
        }

        function test_placeholders() {
            LabLang.lang = "de"
            compare(LabLang.tf("tst.args", 2, 3), "2 von 3")
        }

        function test_numbersPerLanguage() {
            compare(LabLang.decimalPoint, ".")
            compare(LabLang.num(4.32, 2), "4.32")
            compare(LabLang.num(0.5), "0.5")
            compare(LabLang.qty(0.05, "A"), "50.0 mA")
            LabLang.lang = "de"
            compare(LabLang.decimalPoint, ",")
            compare(LabLang.num(4.32, 2), "4,32")
            compare(LabLang.num(0.5), "0,5")
            compare(LabLang.num(12, 0), "12")
            compare(LabLang.qty(0.05, "A"), "50,0 mA")
            compare(LabLang.qty(1500, "Ω"), "1,50 kΩ")
        }
    }
}
