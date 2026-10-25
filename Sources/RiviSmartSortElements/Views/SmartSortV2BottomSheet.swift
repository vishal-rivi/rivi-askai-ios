import SwiftUI

/// The Smart Sort V2 ask sheet.
///
/// A header with an animated `SmartSortSparkle` and "Smart Sort"; a short
/// description; the query input; suggestion chips; an optional inline error with "Try again";
/// and an "Improve Results" button. While the input is empty its placeholder types out example
/// queries word by word, holds, fades and moves to the next, like `SmartSortPromptResultCard`.
///
/// Improve Results (or tapping a suggestion, which adds it to the query) calls `onSubmit` and
/// closes the sheet; progress and errors show on the results screen, e.g. in
/// `SmartSortV2DynamicBanner`.
public struct SmartSortV2BottomSheet: View {
    // MARK: - Configuration

    public struct Configuration {
        // MARK: - Text
        /// The title next to the sparkle.
        public var titleText: String
        /// The line under the title. Empty uses the flight or hotel default.
        public var descriptionText: String
        /// Shows "Your filters (Nonstop, Morning) will now be used to rank flights." under the
        /// description, when `filterLabels` are passed. Off by default.
        public var showsFiltersNote: Bool
        /// The static input placeholder, used when `animatesPlaceholder` is false. Empty uses the
        /// flight or hotel default.
        public var placeholderText: String
        /// Types example queries into the empty input instead of `placeholderText`.
        public var animatesPlaceholder: Bool
        /// The examples the placeholder cycles through. Empty uses the flight or hotel defaults.
        public var placeholderExamples: [String]
        /// Shown before each example.
        public var examplePrefix: String
        /// How the examples type out, hold and fade.
        public var exampleAnimation: SmartSortExampleAnimation
        /// The suggestion chips. Empty uses the flight or hotel defaults.
        public var suggestions: [String]
        /// The submit button text.
        public var submitButtonText: String
        /// The inline error message.
        public var errorText: String
        /// The inline error's retry button text.
        public var retryButtonText: String
        /// Maximum number of characters in the query.
        public var characterLimit: Int

        // MARK: - Fonts
        public var titleFont: Font
        public var descriptionFont: Font
        public var filtersNoteFont: Font
        public var inputFont: Font
        public var suggestionFont: Font
        public var submitButtonFont: Font
        public var errorFont: Font
        public var retryButtonFont: Font

        // MARK: - Layout
        /// Padding inside the sheet. The top leaves room for the drag indicator.
        public var padding: EdgeInsets
        /// Lines the input shows (and reserves) before it scrolls.
        public var inputLineLimit: Int
        /// The header sparkle's size.
        public var sparkleSize: CGFloat
        /// The sheet's top corner radius (iOS 16.4+).
        public var sheetCornerRadius: CGFloat
        /// The input's corner radius.
        public var inputCornerRadius: CGFloat
        /// The submit button's height.
        public var submitButtonHeight: CGFloat
        /// The submit button's corner radius. nil (the default) makes it a capsule.
        public var submitButtonCornerRadius: CGFloat?
        /// Shows the sparkle before the submit button's text. true by default.
        public var showsSubmitButtonIcon: Bool
        /// The submit button's text while it's disabled (empty input). nil uses `submitButtonTextColor`.
        public var submitButtonDisabledTextColor: Color? = nil
        /// Shows "Clear All" in the header while the input has text or a query is active (it
        /// also needs `onClearAll`). false by default.
        public var showsClearAllButton: Bool = false
        public var clearAllButtonText: String = "chips_clear_all_button".localized()
        public var clearAllButtonFont: Font = .system(size: 14, weight: .regular)
        public var clearAllButtonColor: Color = AppColor.smartSortAccent

        // MARK: - Colors
        public var backgroundColor: Color
        public var titleColor: Color
        public var sparkleConfiguration: SmartSortSparkle.Configuration
        public var descriptionColor: Color
        public var filtersNoteColor: Color
        public var filtersNoteIconColor: Color
        public var closeButtonBackgroundColor: Color
        public var closeButtonColor: Color
        public var inputBackgroundColor: Color
        public var inputBorderColor: Color
        /// The input border, and a soft ring around it, while focused.
        public var inputFocusedBorderColor: Color
        public var textColor: Color
        public var placeholderColor: Color
        public var suggestionBorderColor: Color
        public var suggestionTextColor: Color
        /// Chip border and text when the chip is part of the query.
        public var suggestionSelectedColor: Color
        public var suggestionSelectedBackgroundColor: Color
        public var submitButtonBackgroundColor: Color
        public var submitButtonDisabledBackgroundColor: Color
        public var submitButtonTextColor: Color
        public var errorBackgroundColor: Color
        public var errorBorderColor: Color
        public var errorTextColor: Color
        public var retryButtonBackgroundColor: Color

        /// The Smart Sort V2 design.
        public static var `default`: Configuration {
            Configuration(
                titleText: "smart_sort_sheet_title".localized(),
                descriptionText: "",
                showsFiltersNote: false,
                placeholderText: "",
                animatesPlaceholder: true,
                placeholderExamples: [],
                examplePrefix: "smart_sort_prompt_example_prefix".localized(),
                exampleAnimation: .default,
                suggestions: [],
                submitButtonText: "smart_sort_v2_submit_button".localized(),
                errorText: "smart_sort_v2_error".localized(),
                retryButtonText: "smart_sort_v2_retry_button".localized(),
                characterLimit: 200,
                titleFont: .system(size: 18, weight: .bold),
                descriptionFont: .system(size: 14, weight: .regular),
                filtersNoteFont: .system(size: 12.5, weight: .regular),
                inputFont: .system(size: 15, weight: .regular),
                suggestionFont: .system(size: 14, weight: .regular),
                submitButtonFont: .system(size: 16, weight: .semibold),
                errorFont: .system(size: 13, weight: .regular),
                retryButtonFont: .system(size: 13, weight: .semibold),
                padding: EdgeInsets(top: 24, leading: 16, bottom: 16, trailing: 16),
                inputLineLimit: 3,
                sparkleSize: 22,
                sheetCornerRadius: 28,
                inputCornerRadius: 12,
                submitButtonHeight: 52,
                backgroundColor: AppColor.background,
                titleColor: Color(light: "#1B1B1F", dark: "#FAFAFA"),
                sparkleConfiguration: .default,
                descriptionColor: Color(light: "#6B6B75", dark: "#8D9195"),
                filtersNoteColor: Color(light: "#6E6880", dark: "#8D9195"),
                filtersNoteIconColor: AppColor.smartSortAccent,
                closeButtonBackgroundColor: Color(light: "#F2F2F5", dark: "#323335"),
                closeButtonColor: Color(light: "#3A3A42", dark: "#FAFAFA"),
                inputBackgroundColor: AppColor.background,
                inputBorderColor: Color(light: "#DDD0FA", dark: "#4A3D6B"),
                inputFocusedBorderColor: Color(light: "#9D74EE", dark: "#9D74EE"),
                textColor: Color(light: "#1B1B1F", dark: "#FAFAFA"),
                placeholderColor: Color(light: "#9A9AA3", dark: "#8D9195"),
                suggestionBorderColor: Color(light: "#E1E1E6", dark: "#414346"),
                suggestionTextColor: Color(light: "#1B1B1F", dark: "#FAFAFA"),
                suggestionSelectedColor: AppColor.smartSortAccent,
                suggestionSelectedBackgroundColor: Color(light: "#F4EFFE", dark: "#2E2547"),
                submitButtonBackgroundColor: AppColor.smartSortButton,
                submitButtonDisabledBackgroundColor: AppColor.smartSortButtonDisabled,
                submitButtonTextColor: AppColor.color2,
                errorBackgroundColor: Color(light: "#FDF0F2", dark: "#3A1F24"),
                errorBorderColor: Color(light: "#F5C6CF", dark: "#6B2A35"),
                errorTextColor: Color(light: "#C0263C", dark: "#FF8A9B"),
                retryButtonBackgroundColor: AppColor.background
            )
        }

        public init(
            titleText: String,
            descriptionText: String,
            showsFiltersNote: Bool,
            placeholderText: String,
            animatesPlaceholder: Bool,
            placeholderExamples: [String],
            examplePrefix: String,
            exampleAnimation: SmartSortExampleAnimation,
            suggestions: [String],
            submitButtonText: String,
            errorText: String,
            retryButtonText: String,
            characterLimit: Int,
            titleFont: Font,
            descriptionFont: Font,
            filtersNoteFont: Font,
            inputFont: Font,
            suggestionFont: Font,
            submitButtonFont: Font,
            errorFont: Font,
            retryButtonFont: Font,
            padding: EdgeInsets,
            inputLineLimit: Int,
            sparkleSize: CGFloat,
            sheetCornerRadius: CGFloat,
            inputCornerRadius: CGFloat,
            submitButtonHeight: CGFloat,
            backgroundColor: Color,
            titleColor: Color,
            sparkleConfiguration: SmartSortSparkle.Configuration,
            descriptionColor: Color,
            filtersNoteColor: Color,
            filtersNoteIconColor: Color,
            closeButtonBackgroundColor: Color,
            closeButtonColor: Color,
            inputBackgroundColor: Color,
            inputBorderColor: Color,
            inputFocusedBorderColor: Color,
            textColor: Color,
            placeholderColor: Color,
            suggestionBorderColor: Color,
            suggestionTextColor: Color,
            suggestionSelectedColor: Color,
            suggestionSelectedBackgroundColor: Color,
            submitButtonBackgroundColor: Color,
            submitButtonDisabledBackgroundColor: Color,
            submitButtonTextColor: Color,
            errorBackgroundColor: Color,
            errorBorderColor: Color,
            errorTextColor: Color,
            retryButtonBackgroundColor: Color,
            submitButtonCornerRadius: CGFloat? = nil,
            showsSubmitButtonIcon: Bool = true
        ) {
            self.titleText = titleText
            self.descriptionText = descriptionText
            self.showsFiltersNote = showsFiltersNote
            self.placeholderText = placeholderText
            self.animatesPlaceholder = animatesPlaceholder
            self.placeholderExamples = placeholderExamples
            self.examplePrefix = examplePrefix
            self.exampleAnimation = exampleAnimation
            self.suggestions = suggestions
            self.submitButtonText = submitButtonText
            self.errorText = errorText
            self.retryButtonText = retryButtonText
            self.characterLimit = characterLimit
            self.titleFont = titleFont
            self.descriptionFont = descriptionFont
            self.filtersNoteFont = filtersNoteFont
            self.inputFont = inputFont
            self.suggestionFont = suggestionFont
            self.submitButtonFont = submitButtonFont
            self.errorFont = errorFont
            self.retryButtonFont = retryButtonFont
            self.padding = padding
            self.inputLineLimit = inputLineLimit
            self.sparkleSize = sparkleSize
            self.sheetCornerRadius = sheetCornerRadius
            self.inputCornerRadius = inputCornerRadius
            self.submitButtonHeight = submitButtonHeight
            self.backgroundColor = backgroundColor
            self.titleColor = titleColor
            self.sparkleConfiguration = sparkleConfiguration
            self.descriptionColor = descriptionColor
            self.filtersNoteColor = filtersNoteColor
            self.filtersNoteIconColor = filtersNoteIconColor
            self.closeButtonBackgroundColor = closeButtonBackgroundColor
            self.closeButtonColor = closeButtonColor
            self.inputBackgroundColor = inputBackgroundColor
            self.inputBorderColor = inputBorderColor
            self.inputFocusedBorderColor = inputFocusedBorderColor
            self.textColor = textColor
            self.placeholderColor = placeholderColor
            self.suggestionBorderColor = suggestionBorderColor
            self.suggestionTextColor = suggestionTextColor
            self.suggestionSelectedColor = suggestionSelectedColor
            self.suggestionSelectedBackgroundColor = suggestionSelectedBackgroundColor
            self.submitButtonBackgroundColor = submitButtonBackgroundColor
            self.submitButtonDisabledBackgroundColor = submitButtonDisabledBackgroundColor
            self.submitButtonTextColor = submitButtonTextColor
            self.errorBackgroundColor = errorBackgroundColor
            self.errorBorderColor = errorBorderColor
            self.errorTextColor = errorTextColor
            self.retryButtonBackgroundColor = retryButtonBackgroundColor
            self.submitButtonCornerRadius = submitButtonCornerRadius
            self.showsSubmitButtonIcon = showsSubmitButtonIcon
        }
    }

    // MARK: - State

    @State private var userQuery: String
    @State private var contentHeight: CGFloat = 420
    @State private var lastTypedAt: Date?
    @State private var sparkleTrigger = 0
    /// The placeholder example on screen.
    @State private var placeholderIndex: Int
    @FocusState private var isInputFocused: Bool

    /// The header sparkle rests while the user has typed in the last few seconds.
    private let typingQuietPeriod: TimeInterval = 3

    // MARK: - Properties

    private let configuration: Configuration
    @Binding private var isPresented: Bool
    private let isShowingError: Bool
    private let focusesInputOnAppear: Bool
    /// "Your filters (…) will now be used to rank flights.", or nil when hidden.
    private let filtersNote: String?
    private let onSubmit: (String) -> Void
    private let onRetry: (() -> Void)?
    private let onQueryChange: ((String) -> Void)?
    private let hasActiveQuery: Bool
    private let onClearAll: (() -> Void)?

    // MARK: - Initialization

    /// - Parameters:
    ///   - configuration: Text, fonts, layout and colors (defaults to `.default`).
    ///   - isPresented: Controls the sheet. Submitting sets it to false.
    ///   - queryType: Picks the flight or hotel description, placeholder and suggestions.
    ///   - userQuery: Text to prefill the input with (the active query).
    ///   - startingExample: The placeholder example to start on, e.g. the one a prompt card showed.
    ///   - filterLabels: Your applied filters in words ("Nonstop", "Morning"), for the note under the
    ///     description. Shown only with `configuration.showsFiltersNote`.
    ///   - isShowingError: Shows the inline error, e.g. when reopening after a failed request.
    ///   - focusesInputOnAppear: Opens the keyboard once the sheet is up (e.g. from a prompt card).
    ///   - onSubmit: Called with the trimmed query, from the button or a suggestion.
    ///   - onRetry: Called by the error's "Try again". Defaults to submitting the query again.
    ///   - onQueryChange: Called as the user edits the query, e.g. to dismiss an error.
    ///   - hasActiveQuery: A query is applied, so "Clear All" shows even with an empty input.
    ///   - onClearAll: "Clear All" (with `configuration.showsClearAllButton`): the input is emptied
    ///     and the sheet stays open; clear the applied query and filters here.
    public init(
        configuration: Configuration = .default,
        isPresented: Binding<Bool>,
        queryType: QueryType,
        userQuery: String = "",
        startingExample: String? = nil,
        filterLabels: [String] = [],
        isShowingError: Bool = false,
        focusesInputOnAppear: Bool = false,
        onSubmit: @escaping (String) -> Void,
        onRetry: (() -> Void)? = nil,
        onQueryChange: ((String) -> Void)? = nil,
        hasActiveQuery: Bool = false,
        onClearAll: (() -> Void)? = nil
    ) {
        var resolved = configuration
        let isHotel = queryType == .hotel
        if resolved.descriptionText.isEmpty {
            resolved.descriptionText = (isHotel ? "smart_sort_v2_description_hotel" : "smart_sort_v2_description_flight").localized()
        }
        if resolved.placeholderText.isEmpty {
            resolved.placeholderText = (isHotel ? "smart_sort_v2_placeholder_hotel" : "smart_sort_v2_placeholder_flight").localized()
        }
        if resolved.placeholderExamples.isEmpty {
            let prefix = isHotel ? "smart_sort_prompt_example_hotel_" : "smart_sort_prompt_example_flight_"
            resolved.placeholderExamples = (1...5).map { (prefix + "\($0)").localized() }
        }
        var startIndex = 0
        if let startingExample, !startingExample.isEmpty {
            if let index = resolved.placeholderExamples.firstIndex(of: startingExample) {
                startIndex = index
            } else {
                resolved.placeholderExamples.insert(startingExample, at: 0)
            }
        }
        if resolved.suggestions.isEmpty {
            let prefix = isHotel ? "smart_sort_v2_suggestion_hotel_" : "smart_sort_v2_suggestion_flight_"
            resolved.suggestions = (1...4).map { (prefix + "\($0)").localized() }
        }
        self.configuration = resolved
        self._isPresented = isPresented
        self._userQuery = State(initialValue: userQuery)
        self._placeholderIndex = State(initialValue: startIndex)
        let noteKey = isHotel ? "smart_sort_v2_filters_note_hotel" : "smart_sort_v2_filters_note_flight"
        self.filtersNote = resolved.showsFiltersNote && !filterLabels.isEmpty
            ? String(format: noteKey.localized(), filterLabels.joined(separator: ", "))
            : nil
        self.isShowingError = isShowingError
        self.focusesInputOnAppear = focusesInputOnAppear
        self.onSubmit = onSubmit
        self.onRetry = onRetry
        self.onQueryChange = onQueryChange
        self.hasActiveQuery = hasActiveQuery
        self.onClearAll = onClearAll
    }

    // MARK: - Body

    public var body: some View {
        let sheet = content()
            .readSize { size in
                if size.height > 0 && abs(size.height - contentHeight) > 0.5 { contentHeight = size.height }
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .environment(\.layoutDirection, RiviSmartSortConfiguration.shared.language.layoutDirection)
            .presentationDetents([.height(contentHeight)])
            .presentationDragIndicator(.visible)

        if #available(iOS 16.4, *) {
            sheet
                .presentationCornerRadius(configuration.sheetCornerRadius)
                .presentationBackground(configuration.backgroundColor)
        } else {
            sheet.background(configuration.backgroundColor)
        }
    }

    // MARK: - Content

    @ViewBuilder
    private func content() -> some View {
        VStack(alignment: .leading, spacing: 0) {
            header()
            Text(configuration.descriptionText)
                .font(configuration.descriptionFont)
                .foregroundStyle(configuration.descriptionColor)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)
            if let filtersNote {
                HStack(alignment: .top, spacing: 7) {
                    Image("ic_smart_sort_filter", bundle: .module) // the design's funnel
                        .resizable()
                        .renderingMode(.template)
                        .frame(width: 13, height: 13)
                        .foregroundStyle(configuration.filtersNoteIconColor)
                        .padding(.top, 2)
                        .accessibilityHidden(true)
                    Text(filtersNote)
                        .font(configuration.filtersNoteFont)
                        .foregroundStyle(configuration.filtersNoteColor)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 8)
            }
            input()
                .padding(.top, 16)
            suggestions()
                .padding(.top, 12)
            if isShowingError {
                errorBanner()
                    .padding(.top, 12)
                    .transition(.opacity)
            }
            submitButton()
                .padding(.top, 16)
        }
        .padding(configuration.padding)
        .animation(.easeInOut(duration: 0.2), value: isShowingError)
    }

    @ViewBuilder
    private func header() -> some View {
        HStack(spacing: 8) {
            SmartSortSparkle(
                size: configuration.sparkleSize,
                configuration: headerSparkleConfiguration,
                isBreathing: !isTypingRecently,
                twinkleTrigger: sparkleTrigger
            )
            Text(configuration.titleText)
                .font(configuration.titleFont)
                .foregroundStyle(configuration.titleColor)
                .lineLimit(1)
            Spacer(minLength: 8)
            if configuration.showsClearAllButton, let onClearAll, hasActiveQuery || !trimmedQuery.isEmpty {
                Button {
                    userQuery = ""
                    onClearAll()
                } label: {
                    Text(configuration.clearAllButtonText)
                        .font(configuration.clearAllButtonFont)
                        .foregroundStyle(configuration.clearAllButtonColor)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 2)
                }
                .buttonStyle(.plain)
            }
            Button {
                isPresented = false
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(configuration.closeButtonColor)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(configuration.closeButtonBackgroundColor))
            }
            .accessibilityLabel(Text("smart_sort_sheet_close_accessibility".localized()))
        }
        // The sheet twinkles shortly after opening and then every interval, unless the user is typing.
        .task {
            try? await Task.sleep(nanoseconds: 450_000_000)
            while !Task.isCancelled {
                if !isTypingRecently { sparkleTrigger += 1 }
                let interval = configuration.sparkleConfiguration.twinkleInterval ?? 6
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
        }
    }

    @ViewBuilder
    private func input() -> some View {
        let borderColor = isInputFocused ? configuration.inputFocusedBorderColor : configuration.inputBorderColor
        TextField(
            "",
            text: $userQuery,
            prompt: configuration.animatesPlaceholder ? nil : Text(configuration.placeholderText).foregroundColor(configuration.placeholderColor),
            axis: .vertical
        )
        .font(configuration.inputFont)
        .foregroundStyle(configuration.textColor)
        .lineLimit(configuration.inputLineLimit, reservesSpace: true)
        .focused($isInputFocused)
        .overlay(alignment: .topLeading) {
            if configuration.animatesPlaceholder && userQuery.isEmpty {
                SmartSortExampleTicker(
                    examples: configuration.placeholderExamples,
                    prefix: configuration.examplePrefix,
                    animation: configuration.exampleAnimation,
                    isRunning: true, // restarts the current example whenever the input empties again
                    index: $placeholderIndex
                )
                .font(configuration.inputFont)
                .foregroundStyle(configuration.placeholderColor)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: configuration.inputCornerRadius)
                .fill(configuration.inputBackgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: configuration.inputCornerRadius)
                .stroke(borderColor, lineWidth: 1)
        )
        .background(
            RoundedRectangle(cornerRadius: configuration.inputCornerRadius + 3)
                .stroke(configuration.inputFocusedBorderColor.opacity(isInputFocused ? 0.15 : 0.05), lineWidth: isInputFocused ? 4 : 3)
                .padding(-2)
        )
        .animation(.easeInOut(duration: 0.15), value: isInputFocused)
        .task {
            guard focusesInputOnAppear else { return }
            try? await Task.sleep(nanoseconds: 320_000_000) // after the sheet settles
            isInputFocused = true
        }
        .onChange(of: userQuery) { newValue in
            if newValue.count > configuration.characterLimit {
                userQuery = String(newValue.prefix(configuration.characterLimit))
                return
            }
            lastTypedAt = Date()
            onQueryChange?(newValue)
        }
    }

    @ViewBuilder
    private func suggestions() -> some View {
        SmartSortFlowLayout(spacing: 8) {
            ForEach(configuration.suggestions, id: \.self) { suggestion in
                let isSelected = isInQuery(suggestion)
                Button {
                    submit(adding: suggestion)
                } label: {
                    Text(suggestion)
                        .font(configuration.suggestionFont)
                        .foregroundStyle(isSelected ? configuration.suggestionSelectedColor : configuration.suggestionTextColor)
                        .lineLimit(1)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(isSelected ? configuration.suggestionSelectedBackgroundColor : Color.clear))
                        .overlay(Capsule().stroke(isSelected ? configuration.suggestionSelectedColor : configuration.suggestionBorderColor, lineWidth: 1))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }

    @ViewBuilder
    private func errorBanner() -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 16, weight: .medium))
            Text(configuration.errorText)
                .font(configuration.errorFont)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            Button {
                if let onRetry { onRetry() } else { submit() }
            } label: {
                Text(configuration.retryButtonText)
                    .font(configuration.retryButtonFont)
                    .lineLimit(1)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(RoundedRectangle(cornerRadius: 8).fill(configuration.retryButtonBackgroundColor))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(configuration.errorBorderColor, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(configuration.errorTextColor)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(configuration.errorBackgroundColor))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(configuration.errorBorderColor, lineWidth: 1))
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func submitButton() -> some View {
        let background = canSubmit ? configuration.submitButtonBackgroundColor : configuration.submitButtonDisabledBackgroundColor
        Button {
            submit()
        } label: {
            HStack(spacing: 8) {
                if configuration.showsSubmitButtonIcon {
                    SmartSortSparkle(size: 16, configuration: .plain(configuration.submitButtonTextColor), isAnimating: false)
                }
                Text(configuration.submitButtonText)
                    .font(configuration.submitButtonFont)
                    .lineLimit(1)
            }
            .foregroundStyle(canSubmit ? configuration.submitButtonTextColor
                             : configuration.submitButtonDisabledTextColor ?? configuration.submitButtonTextColor)
            .frame(maxWidth: .infinity)
            .frame(height: configuration.submitButtonHeight)
            .background(submitButtonShape.fill(background))
            .shadow(color: configuration.submitButtonBackgroundColor.opacity(canSubmit ? 0.28 : 0), radius: 8, y: 6)
        }
        // Not `.plain`: it dims a disabled button on top of the disabled colors, which washes them out.
        .buttonStyle(SmartSortUndimmedButtonStyle())
        .disabled(!canSubmit)
    }

    /// A rounded rectangle with `submitButtonCornerRadius`, or a capsule when it's nil.
    private var submitButtonShape: AnyShape {
        if let radius = configuration.submitButtonCornerRadius {
            return AnyShape(RoundedRectangle(cornerRadius: radius))
        }
        return AnyShape(Capsule())
    }

    // MARK: - Actions

    private var trimmedQuery: String {
        userQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSubmit: Bool { !trimmedQuery.isEmpty }

    private var isTypingRecently: Bool {
        guard let lastTypedAt else { return false }
        return Date().timeIntervalSince(lastTypedAt) < typingQuietPeriod
    }

    /// The header sparkle's twinkles are scheduled by this sheet, so they can pause while typing.
    private var headerSparkleConfiguration: SmartSortSparkle.Configuration {
        var sparkle = configuration.sparkleConfiguration
        sparkle.twinkleInterval = nil
        return sparkle
    }

    /// The query's parts (split at ".", "," or ";"), lowercased.
    private var queryParts: [String] {
        trimmedQuery.split(whereSeparator: { ".,;".contains($0) })
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
    }

    private func isInQuery(_ suggestion: String) -> Bool {
        queryParts.contains(suggestion.lowercased())
    }

    /// Sends the query and closes the sheet.
    private func submit() {
        guard canSubmit else { return }
        isInputFocused = false
        onSubmit(trimmedQuery)
        isPresented = false
    }

    /// Runs Smart Sort with the suggestion: on its own when the input is empty, otherwise added
    /// after what's there ("Avoid long layovers. Depart after work"), never replacing it. A
    /// suggestion already in the query isn't added twice.
    private func submit(adding suggestion: String) {
        if !isInQuery(suggestion) {
            var typed = trimmedQuery
            while let last = typed.last, ".,;".contains(last) || last.isWhitespace { typed.removeLast() }
            let combined = typed.isEmpty ? suggestion : typed + ". " + suggestion
            userQuery = String(combined.prefix(configuration.characterLimit))
        }
        submit()
    }
}

// MARK: - Flow layout

/// Lays its children out in rows, wrapping to a new row when the next one doesn't fit.
struct SmartSortFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(subviews, width: proposal.width ?? .infinity)
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(subviews, width: bounds.width) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(_ subviews: Subviews, width: CGFloat) -> [Row] {
        var rows: [Row] = []
        var row = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = row.indices.isEmpty ? size.width : row.width + spacing + size.width
            if needed > width && !row.indices.isEmpty {
                rows.append(row)
                row = Row()
            }
            row.width = row.indices.isEmpty ? size.width : row.width + spacing + size.width
            row.height = max(row.height, size.height)
            row.indices.append(index)
        }
        if !row.indices.isEmpty { rows.append(row) }
        return rows
    }
}

/// Shows the label as is, pressed or disabled: the colors already say whether it can be tapped.
/// (`.disabled` still turns off taps and tells VoiceOver.)
struct SmartSortUndimmedButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.85 : 1)
            .contentShape(Rectangle())
    }
}
