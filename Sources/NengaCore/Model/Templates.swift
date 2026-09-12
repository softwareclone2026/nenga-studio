import Foundation

/// 文面テンプレート。すべてこのリポジトリ用に作ったオリジナルデザイン。
public struct NengaTemplate: Sendable, Identifiable {
    public let id: String
    public let name: String
    public let category: String
    public let summary: String
    public let paletteName: String
    /// 干支を使うテンプレートは年ごとに絵柄が変わる
    public let usesZodiac: Bool
    public let make: @Sendable (Int) -> DesignPage

    public init(
        id: String,
        name: String,
        category: String,
        summary: String,
        paletteName: String,
        usesZodiac: Bool,
        make: @escaping @Sendable (Int) -> DesignPage
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.summary = summary
        self.paletteName = paletteName
        self.usesZodiac = usesZodiac
        self.make = make
    }
}

/// 文面を組み立てるための小さなヘルパー。
struct DesignBuilder {
    var elements: [DesignElement] = []
    var paperColor: RGBColor
    let palette: Palette

    init(palette: Palette, paperColor: RGBColor? = nil) {
        self.palette = palette
        self.paperColor = paperColor ?? palette.paper
    }

    mutating func text(
        _ text: String,
        x: Double,
        y: Double,
        width: Double,
        height: Double,
        size: Double,
        direction: TextDirection = .vertical,
        font: FontChoice = .mincho,
        weight: FontWeight = .regular,
        alignment: TextAlignmentOption = .center,
        letterSpacing: Double = 0,
        lineSpacing: Double = 0,
        opacity: Double = 1,
        usesPlaceholders: Bool = false,
        color: RGBColor? = nil,
        name: String = "テキスト"
    ) {
        elements.append(
            .text(
                TextElement(
                    name: name,
                    frame: ElementFrame(x: x, y: y, width: width, height: height),
                    text: text,
                    font: font,
                    weight: weight,
                    sizeMM: size,
                    color: color ?? palette.ink,
                    direction: direction,
                    alignment: alignment,
                    letterSpacingMM: letterSpacing,
                    lineSpacingMM: lineSpacing,
                    usesPlaceholders: usesPlaceholders,
                    opacity: opacity
                )
            )
        )
    }

    mutating func motif(
        _ kind: MotifKind,
        x: Double,
        y: Double,
        width: Double,
        height: Double,
        lineWidth: Double = 0.5,
        opacity: Double = 1,
        color: RGBColor? = nil,
        name: String? = nil
    ) {
        elements.append(
            .motif(
                MotifElement(
                    name: name,
                    frame: ElementFrame(x: x, y: y, width: width, height: height),
                    kind: kind,
                    paletteName: palette.name,
                    overrideColor: color,
                    lineWidthMM: lineWidth,
                    opacity: opacity
                )
            )
        )
    }

    mutating func shape(
        _ kind: ShapeKind,
        x: Double,
        y: Double,
        width: Double,
        height: Double,
        fill: RGBColor? = nil,
        stroke: RGBColor? = nil,
        strokeWidth: Double = 0.4,
        cornerRadius: Double = 3,
        opacity: Double = 1,
        name: String = "図形"
    ) {
        elements.append(
            .shape(
                ShapeElement(
                    name: name,
                    frame: ElementFrame(x: x, y: y, width: width, height: height),
                    kind: kind,
                    fill: fill,
                    stroke: stroke,
                    strokeWidthMM: strokeWidth,
                    cornerRadiusMM: cornerRadius,
                    opacity: opacity
                )
            )
        )
    }

    mutating func photoFrame(
        x: Double,
        y: Double,
        width: Double,
        height: Double,
        name: String = "写真"
    ) {
        elements.append(
            .image(
                ImageElement(
                    name: name,
                    frame: ElementFrame(x: x, y: y, width: width, height: height),
                    assetFileName: ""
                )
            )
        )
    }

    func build(templateID: String) -> DesignPage {
        DesignPage(paperColor: paperColor, elements: elements, templateID: templateID)
    }
}

public enum NengaTemplates {
    public static let defaultTemplateID = "kingu-shinnen-sheep"

    public static let all: [NengaTemplate] = [
        NengaTemplate(
            id: "kingu-shinnen-sheep",
            name: "謹賀新年（干支と松竹梅）",
            category: "和風",
            summary: "右に縦書きの賀詞、左に干支のイラストを配した王道の年賀状。",
            paletteName: Palette.kohaku.name,
            usesZodiac: true
        ) { year in
            var builder = DesignBuilder(palette: .kohaku)
            builder.motif(.goldCloud, x: -6, y: -8, width: 92, height: 30, opacity: 0.55)
            builder.motif(.goldCloud, x: 92, y: 78, width: 70, height: 26, opacity: 0.4)
            builder.motif(.zodiacAnimal, x: 20, y: 20, width: 50, height: 44, lineWidth: 0.6)
            builder.motif(.pineBambooPlum, x: 12, y: 66, width: 42, height: 30, lineWidth: 0.45, opacity: 0.95)
            builder.text(
                "謹賀新年",
                x: 112, y: 14, width: 16, height: 62,
                size: 12.5, weight: .bold, letterSpacing: 1.4,
                name: "賀詞（謹賀新年）"
            )
            builder.text(
                "\(YearInfo(year: year).wareki) 元旦",
                x: 96, y: 84, width: 44, height: 8,
                size: 4.2, direction: .horizontal, alignment: .center, letterSpacing: 0.3,
                name: "年号"
            )
            return builder.build(templateID: "kingu-shinnen-sheep")
        },

        NengaTemplate(
            id: "akemashite-fuji",
            name: "あけましておめでとう（富士）",
            category: "和風",
            summary: "富士山と日の出を大きくあしらった、縁起の良い一枚。",
            paletteName: Palette.ai.name,
            usesZodiac: false
        ) { year in
            var builder = DesignBuilder(palette: .ai)
            builder.motif(.goldCloud, x: 96, y: -6, width: 60, height: 26, opacity: 0.5)
            builder.motif(.fuji, x: 14, y: 30, width: 66, height: 54, lineWidth: 0.5)
            builder.motif(.zodiacKanji, x: 106, y: 62, width: 30, height: 30, lineWidth: 0.5, opacity: 0.9)
            builder.text(
                "あけまして\nおめでとう\nございます",
                x: 98, y: 12, width: 44, height: 46,
                size: 6.4, letterSpacing: 1.0, lineSpacing: 2.6,
                name: "賀詞（あけまして）"
            )
            builder.text(
                "本年もよろしくお願い申し上げます",
                x: 40, y: 88, width: 96, height: 7,
                size: 3.6, direction: .horizontal, alignment: .trailing, letterSpacing: 0.4,
                name: "添え書き"
            )
            builder.text(
                YearInfo(year: year).western,
                x: 12, y: 87, width: 26, height: 8,
                size: 4.0, direction: .horizontal, alignment: .leading,
                color: Palette.ai.secondary,
                name: "西暦"
            )
            return builder.build(templateID: "akemashite-fuji")
        },

        NengaTemplate(
            id: "geishun-matsu",
            name: "迎春（松と水引）",
            category: "和風",
            summary: "余白を広くとった落ち着いたデザイン。目上の方にも。",
            paletteName: Palette.matcha.name,
            usesZodiac: false
        ) { year in
            var builder = DesignBuilder(palette: .matcha)
            builder.motif(.pine, x: 20, y: 18, width: 54, height: 64, lineWidth: 0.5)
            builder.motif(.mizuhiki, x: 88, y: 66, width: 34, height: 20, lineWidth: 0.5)
            builder.text(
                "迎春",
                x: 112, y: 16, width: 18, height: 34,
                size: 15, weight: .bold, letterSpacing: 1.0,
                name: "賀詞（迎春）"
            )
            builder.text(
                "\(YearInfo(year: year).wareki)",
                x: 104, y: 52, width: 34, height: 7,
                size: 4.0, direction: .horizontal, alignment: .center,
                color: Palette.matcha.primary,
                name: "年号"
            )
            builder.text(
                "今年もどうぞよろしくお願いいたします",
                x: 30, y: 86, width: 80, height: 7,
                size: 3.5, direction: .horizontal, alignment: .center, letterSpacing: 0.3,
                name: "添え書き"
            )
            return builder.build(templateID: "geishun-matsu")
        },

        NengaTemplate(
            id: "shinshun-ogi",
            name: "新春（扇と金雲）",
            category: "和風",
            summary: "扇と金雲で華やかに。ご家族宛てにも映えるデザイン。",
            paletteName: Palette.kohaku.name,
            usesZodiac: true
        ) { year in
            var builder = DesignBuilder(palette: .kohaku)
            builder.motif(.goldCloud, x: -4, y: 70, width: 156, height: 34, opacity: 0.45)
            builder.motif(.fan, x: 26, y: 20, width: 52, height: 50, lineWidth: 0.55)
            builder.motif(.plum, x: 8, y: 8, width: 34, height: 26, lineWidth: 0.45)
            builder.text(
                "新春のお慶びを\n申し上げます",
                x: 96, y: 16, width: 46, height: 40,
                size: 6.8, letterSpacing: 1.1, lineSpacing: 3.0,
                name: "賀詞（新春）"
            )
            builder.text(
                "\(YearInfo(year: year).zodiac.kanji)年 \(YearInfo(year: year).wareki)",
                x: 88, y: 62, width: 52, height: 7,
                size: 3.8, direction: .horizontal, alignment: .center, letterSpacing: 0.5,
                name: "年号"
            )
            return builder.build(templateID: "shinshun-ogi")
        },

        NengaTemplate(
            id: "simple-kaji",
            name: "シンプル（麻の葉と賀詞）",
            category: "シンプル",
            summary: "文様を淡く敷いた、文字が主役のシンプルな年賀状。",
            paletteName: Palette.sumi.name,
            usesZodiac: false
        ) { year in
            var builder = DesignBuilder(palette: .sumi, paperColor: RGBColor(hex: "FCFCF8"))
            builder.motif(.asanoha, x: 0, y: 0, width: 148, height: 100, lineWidth: 0.25, opacity: 0.28)
            builder.motif(.zodiacKanji, x: 24, y: 30, width: 40, height: 40, lineWidth: 0.5, opacity: 0.85)
            builder.text(
                "謹賀新年",
                x: 92, y: 18, width: 22, height: 66,
                size: 13.5, weight: .bold, letterSpacing: 2.4,
                name: "賀詞（謹賀新年）"
            )
            builder.text(
                "本年もどうぞよろしくお願い申し上げます",
                x: 14, y: 84, width: 76, height: 7,
                size: 3.2, direction: .horizontal, alignment: .leading, letterSpacing: 0.3,
                name: "添え書き"
            )
            builder.text(
                YearInfo(year: year).western,
                x: 116, y: 84, width: 22, height: 7,
                size: 3.2, direction: .horizontal, alignment: .trailing,
                color: Palette.sumi.secondary,
                name: "西暦"
            )
            return builder.build(templateID: "simple-kaji")
        },

        NengaTemplate(
            id: "photo-nenga",
            name: "写真年賀（写真枠つき）",
            category: "写真",
            summary: "写真を 1 枚配置して、右に賀詞を添えるフォト年賀状。",
            paletteName: Palette.momo.name,
            usesZodiac: true
        ) { year in
            var builder = DesignBuilder(palette: .momo)
            builder.motif(.goldCloud, x: 84, y: -6, width: 70, height: 24, opacity: 0.45)
            builder.shape(
                .roundedRectangle,
                x: 12, y: 12, width: 76, height: 62,
                fill: RGBColor(hex: "FFFFFF"),
                stroke: Palette.momo.accent,
                strokeWidth: 0.7,
                cornerRadius: 2,
                name: "写真枠"
            )
            builder.photoFrame(x: 13.5, y: 13.5, width: 73, height: 59, name: "写真")
            builder.motif(.zodiacAnimal, x: 54, y: 74, width: 34, height: 22, lineWidth: 0.45)
            builder.text(
                "あけまして\nおめでとうございます",
                x: 96, y: 14, width: 48, height: 46,
                size: 6.6, weight: .bold, letterSpacing: 1.0, lineSpacing: 3.2,
                name: "賀詞"
            )
            builder.text(
                "{氏名}",
                x: 88, y: 70, width: 58, height: 12,
                size: 4.6, direction: .horizontal, alignment: .trailing, letterSpacing: 0.6,
                usesPlaceholders: true,
                name: "宛名差し込み"
            )
            builder.text(
                YearInfo(year: year).western,
                x: 14, y: 80, width: 34, height: 8,
                size: 4.4, direction: .horizontal, alignment: .leading,
                color: Palette.momo.primary,
                name: "西暦"
            )
            return builder.build(templateID: "photo-nenga")
        },

        NengaTemplate(
            id: "pop-maru",
            name: "ポップ（丸ゴシック）",
            category: "カジュアル",
            summary: "丸ゴシックと明るい配色。友人・同僚向けのカジュアル年賀状。",
            paletteName: Palette.pop.name,
            usesZodiac: true
        ) { year in
            var builder = DesignBuilder(palette: .pop, paperColor: RGBColor(hex: "FFFCF2"))
            builder.motif(.goldCloud, x: 78, y: -10, width: 84, height: 30, opacity: 0.35)
            builder.motif(.zodiacAnimal, x: 22, y: 24, width: 58, height: 52, lineWidth: 0.6)
            builder.text(
                "HAPPY\nNEW YEAR",
                x: 92, y: 12, width: 48, height: 22,
                size: 6.0, direction: .horizontal, font: .maru, weight: .bold,
                alignment: .center, lineSpacing: 1.0,
                color: Palette.pop.primary,
                name: "見出し"
            )
            builder.text(
                "\(year)",
                x: 96, y: 36, width: 40, height: 14,
                size: 10.0, direction: .horizontal, font: .maru, weight: .bold,
                alignment: .center,
                color: Palette.pop.ink,
                name: "西暦"
            )
            builder.text(
                "今年もよろしく！",
                x: 92, y: 56, width: 48, height: 10,
                size: 4.6, direction: .horizontal, font: .maru,
                alignment: .center,
                name: "添え書き"
            )
            return builder.build(templateID: "pop-maru")
        },

        NengaTemplate(
            id: "wa-modern",
            name: "和モダン（七宝に干支）",
            category: "和風",
            summary: "七宝文様と金のアクセントでまとめた、大人向けの年賀状。",
            paletteName: Palette.sumi.name,
            usesZodiac: true
        ) { year in
            var builder = DesignBuilder(palette: .sumi, paperColor: RGBColor(hex: "FBF9F2"))
            builder.shape(
                .rectangle,
                x: 0, y: 0, width: 148, height: 100,
                fill: RGBColor(hex: "23303F"),
                stroke: nil,
                name: "地色"
            )
            builder.motif(.shippo, x: 62, y: 0, width: 86, height: 100, lineWidth: 0.3, opacity: 0.35, color: RGBColor(hex: "7E8CA0"))
            builder.shape(
                .ellipse,
                x: 12, y: 18, width: 44, height: 44,
                fill: RGBColor(hex: "C9A227").withAlpha(0.16),
                stroke: RGBColor(hex: "C9A227"),
                strokeWidth: 0.5,
                name: "金の円"
            )
            builder.motif(.zodiacAnimal, x: 15, y: 21, width: 38, height: 38, lineWidth: 0.5)
            builder.text(
                "賀正",
                x: 18, y: 66, width: 34, height: 24,
                size: 11.0, weight: .bold, letterSpacing: 1.2,
                color: RGBColor(hex: "F3EFE4"),
                name: "賀詞（賀正）"
            )
            builder.text(
                "\(YearInfo(year: year).wareki)",
                x: 14, y: 88, width: 42, height: 7,
                size: 3.4, direction: .horizontal, alignment: .leading, letterSpacing: 0.6,
                color: RGBColor(hex: "C9A227"),
                name: "年号"
            )
            builder.text(
                "皆様のご多幸をお祈り申し上げます",
                x: 66, y: 78, width: 72, height: 7,
                size: 3.3, direction: .horizontal, alignment: .trailing, letterSpacing: 0.4,
                color: RGBColor(hex: "E7E3D8"),
                name: "添え書き"
            )
            return builder.build(templateID: "wa-modern")
        },

        NengaTemplate(
            id: "mochu",
            name: "喪中はがき",
            category: "ご挨拶",
            summary: "年末に送る喪中のご挨拶。南天を控えめに添えた粛々とした構成。",
            paletteName: Palette.sumi.name,
            usesZodiac: false
        ) { year in
            var builder = DesignBuilder(palette: .sumi, paperColor: RGBColor(hex: "FCFCF8"))
            builder.motif(.nandina, x: 96, y: 52, width: 46, height: 44, lineWidth: 0.45, opacity: 0.9)
            builder.text(
                "本年は喪中につき\n年末年始のご挨拶を\n失礼させていただきます",
                x: 16, y: 20, width: 70, height: 40,
                size: 5.4, direction: .horizontal, alignment: .center, lineSpacing: 2.4,
                name: "本文"
            )
            builder.text(
                "本年もお世話になりました",
                x: 16, y: 62, width: 70, height: 8,
                size: 3.4, direction: .horizontal, alignment: .center, letterSpacing: 0.4,
                color: Palette.sumi.secondary,
                name: "添え書き"
            )
            builder.text(
                "\(YearInfo(year: year).wareki) 十二月",
                x: 16, y: 74, width: 70, height: 8,
                size: 3.4, direction: .horizontal, alignment: .center,
                color: Palette.sumi.ink,
                name: "年月"
            )
            return builder.build(templateID: "mochu")
        },

        NengaTemplate(
            id: "kanchu",
            name: "寒中見舞い",
            category: "ご挨拶",
            summary: "1 月に送る寒中見舞い。雪輪と南天の涼やかな一枚。",
            paletteName: Palette.ai.name,
            usesZodiac: false
        ) { year in
            var builder = DesignBuilder(palette: .ai, paperColor: RGBColor(hex: "FBFCFE"))
            builder.motif(.snowRing, x: 6, y: 6, width: 40, height: 40, lineWidth: 0.4, opacity: 0.5)
            builder.motif(.nandina, x: 100, y: 46, width: 42, height: 46, lineWidth: 0.45)
            builder.text(
                "寒中お見舞い\n申し上げます",
                x: 24, y: 24, width: 62, height: 34,
                size: 6.6, direction: .horizontal, alignment: .center, letterSpacing: 0.6, lineSpacing: 2.8,
                name: "見出し"
            )
            builder.text(
                "寒さ厳しき折、どうぞご自愛くださいませ",
                x: 20, y: 66, width: 76, height: 8,
                size: 3.3, direction: .horizontal, alignment: .center, letterSpacing: 0.3,
                name: "本文"
            )
            builder.text(
                "\(YearInfo(year: year).wareki) 一月",
                x: 20, y: 78, width: 76, height: 8,
                size: 3.2, direction: .horizontal, alignment: .center,
                color: Palette.ai.secondary,
                name: "年月"
            )
            return builder.build(templateID: "kanchu")
        },

        NengaTemplate(
            id: "business",
            name: "ビジネス年賀（横書き）",
            category: "ビジネス",
            summary: "会社名と部署を入れた横書きの年賀状。取引先向けに。",
            paletteName: Palette.ai.name,
            usesZodiac: true
        ) { year in
            var builder = DesignBuilder(palette: .ai, paperColor: RGBColor(hex: "FFFFFF"))
            builder.shape(
                .rectangle,
                x: 0, y: 0, width: 148, height: 16,
                fill: Palette.ai.primary,
                stroke: nil,
                name: "帯"
            )
            builder.motif(.zodiacKanji, x: 108, y: 26, width: 32, height: 32, lineWidth: 0.5)
            builder.text(
                "謹んで新春のお慶びを申し上げます",
                x: 12, y: 26, width: 92, height: 10,
                size: 4.8, direction: .horizontal, weight: .bold, alignment: .leading, letterSpacing: 0.5,
                name: "賀詞"
            )
            builder.text(
                "本年も変わらぬご愛顧のほど、よろしくお願い申し上げます。",
                x: 14, y: 42, width: 88, height: 8,
                size: 3.3, direction: .horizontal, alignment: .leading, letterSpacing: 0.2,
                name: "本文"
            )
            builder.text(
                "\(YearInfo(year: year).wareki) 元旦",
                x: 14, y: 54, width: 60, height: 8,
                size: 3.6, direction: .horizontal, alignment: .leading,
                color: Palette.ai.primary,
                name: "年月"
            )
            builder.text(
                "株式会社サンプル\n営業部 御中",
                x: 14, y: 70, width: 90, height: 18,
                size: 3.6, direction: .horizontal, alignment: .leading, lineSpacing: 1.2,
                name: "会社名"
            )
            return builder.build(templateID: "business")
        },
    ]

    public static func template(id: String, year: Int) -> DesignPage? {
        all.first { $0.id == id }?.make(year)
    }

    public static var categories: [String] {
        var seen: [String] = []
        for template in all where !seen.contains(template.category) {
            seen.append(template.category)
        }
        return seen
    }
}
