//
//  PinCodeInputView.swift
//  PinCodeInputView
//
//  Created by Jinsei Shima on 2018/11/06.
//  Copyright © 2018 Jinsei Shima. All rights reserved.
//

import UIKit

@IBDesignable
public class PinCodeInputView<T: UIView & ItemType>: UIControl, UIKeyInput {
    
    private class FakeResponderView: UIView {
        var pasteHandler: ((Any?) -> Void)?
        
        override var canBecomeFirstResponder: Bool {
            return true
        }
        
        override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
            return action == #selector(UIResponderStandardEditActions.paste(_:))
        }
        
        override func paste(_ sender: Any?) {
            self.pasteHandler?(sender)
        }
    }
    
    // MARK: - Properties
    
    private(set) public var text: String = "" {
        didSet {
            if let handler = changeTextHandler {
                handler(text)
            }
            updateText()
        }
    }
    
    public var isEmpty: Bool {
        return text.isEmpty
    }
    
    public var isFilled: Bool {
        return text.count == digit
    }

    public var hasText: Bool {
        return !(text.isEmpty)
    }

    override public var intrinsicContentSize: CGSize {
        return stackView.bounds.size
    }

    private let digit: Int
    private let itemSpacing: CGFloat
    private var changeTextHandler: ((String) -> Void)? = nil
    private var canShowPasteMenuItem: (() -> Bool)? = nil
    private var pasteTextHandler: (() -> String)? = nil
    private let stackView: UIStackView = .init()
    private var items: [ContainerItemView<T>] = []
    private let itemFactory: () -> UIView
    private var appearance: ItemAppearance?
    
    private let fakeResponderView: FakeResponderView = .init()

    // MARK: - UITextInputTraits

    public var autocapitalizationType = UITextAutocapitalizationType.none
    public var autocorrectionType = UITextAutocorrectionType.no
    public var spellCheckingType = UITextSpellCheckingType.no
    public var keyboardType = UIKeyboardType.numberPad
    public var keyboardAppearance = UIKeyboardAppearance.default
    public var returnKeyType = UIReturnKeyType.done
    public var enablesReturnKeyAutomatically = true

    // MARK: - Initializers
    
    public init(
        digit: Int,
        itemSpacing: CGFloat,
        itemFactory: @escaping (() -> T)
    ) {
        
        self.digit = digit
        self.itemSpacing = itemSpacing
        self.itemFactory = itemFactory
        
        super.init(frame: .zero)
        
        self.items = (0..<digit).map { _ in
            let item = ContainerItemView(itemView: itemFactory())
            item.setHandler {
                self.showCursor()
                self.becomeFirstResponder()
            }
            return item
        }
        
        addSubview(self.fakeResponderView)
        addSubview(self.stackView)
        
        items.forEach { stackView.addArrangedSubview($0) }
        stackView.spacing = itemSpacing
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        
        self.fakeResponderView.pasteHandler = { [weak self] sender in
            self?.paste(sender)
        }
        
        let manuLongpressGusture = UILongPressGestureRecognizer.init(target: self, action: #selector((self.menuLongpressGestureHandler(_:))))
        self.addGestureRecognizer(manuLongpressGusture)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Functions

    override public func layoutSubviews() {
        super.layoutSubviews()
        
        guard let appearance = appearance else {
            stackView.frame = bounds
            return
        }
        
        stackView.bounds = CGRect(
            x: 0,
            y: 0,
            width: (appearance.itemSize.width * CGFloat(digit)) + (itemSpacing * CGFloat(digit - 1)),
            height: appearance.itemSize.height
        )
        stackView.center = CGPoint(x: bounds.width / 2, y: bounds.height / 2)
        
        self.fakeResponderView.frame = self.stackView.frame
    }

    public func set(text: String) {
        if Validator.isPinCode(text: text, digit: digit) {
            self.text = text
        }
    }

    public func set(changeTextHandler: @escaping (String) -> ()) {
        self.changeTextHandler = changeTextHandler
    }
    
    public func set(canShowPasteMenuItem: @escaping () -> Bool) {
        self.canShowPasteMenuItem = canShowPasteMenuItem
    }
    
    public func set(pasteTextHandler: @escaping () -> String) {
        self.pasteTextHandler = pasteTextHandler
    }
    
    public func set(appearance: ItemAppearance) {
        self.appearance = appearance
        items.forEach { $0.itemView.set(appearance: appearance) }
    }
    
    private func updateText() {
        
        items.enumerated().forEach { (index, item) in
            if (0..<text.count).contains(index) {
                let _index = text.index(text.startIndex, offsetBy: index)
                item.itemView.text = text[_index]
            } else {
                item.itemView.text = nil
            }
        }
        
        showCursor()
    }
    
    private func showCursor() {
        
        let cursorPosition = text.count
        
        items.enumerated().forEach { (arg) in
            
            let (index, item) = arg
            item.itemView.isHiddenCursor = (index == cursorPosition) ? false : true
        }
    }
    
    private func hiddenCursor() {
        
        items.forEach { $0.itemView.isHiddenCursor = true }
    }
    
    @objc func menuLongpressGestureHandler(_ gestureRecognizer: UILongPressGestureRecognizer) {
        guard gestureRecognizer.state == .began else {
            return
        }
        
        let menu = UIMenuController.shared
        
        guard self.isEnabled, !menu.isMenuVisible else {
            return
        }
        
        guard self.canShowPasteMenuItem?() == true else {
            return
        }
        
        let menuView: UIView
        let menuRect: CGRect
        
        if self.isFirstResponder {
            menuView = self
            menuRect = self.stackView.frame
        } else {
            menuView = self.fakeResponderView
            menuRect = self.fakeResponderView.bounds
            self.fakeResponderView.becomeFirstResponder()
        }
        
        if #available(iOS 13.0, *) {
            menu.showMenu(from: menuView, rect: menuRect)
        } else {
            menu.setTargetRect(CGRect(x: self.stackView.center.x, y: 0, width: 0.0, height: 0.0), in: self)
            menu.setMenuVisible(true, animated: true)
        }
    }
    
    // MARK: - UIKeyInput

    public func insertText(_ textToInsert: String) {
        if isEnabled && text.count + textToInsert.count <= digit && Validator.isOnlyNumeric(text: textToInsert) {
            text.append(textToInsert)
            sendActions(for: .editingChanged)
        }
    }
    
    public func deleteBackward() {
        if isEnabled && !text.isEmpty {
            text.removeLast()
            sendActions(for: .editingChanged)
        }
    }
    
    @available(iOS 12.0, *)
    public var textContentType: UITextContentType! {
        .oneTimeCode
    }

    // MARK: - UIResponder
    
    @discardableResult
    override public func becomeFirstResponder() -> Bool {
        showCursor()
        return super.becomeFirstResponder()
    }
    
    override public var canBecomeFirstResponder: Bool {
        return true
    }

    @discardableResult
    override public func resignFirstResponder() -> Bool {
        hiddenCursor()
        return super.resignFirstResponder()
    }
    
    public override func paste(_ sender: Any?) {
        guard let pasteText = self.pasteTextHandler?(), pasteText.count == self.digit, Validator.isOnlyNumeric(text: pasteText) else {
            return
        }
        
        self.text = pasteText
        self.sendActions(for: .editingChanged)
    }
    
    public override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        return action == #selector(UIResponderStandardEditActions.paste(_:))
    }
 
    // MARK: - private class

    private class ContainerItemView<T: UIView & ItemType>: UIView {
        
        var itemView: T
        private let surfaceView: UIView = .init()
        private var didTapHandler: (() -> ())?
        
        init(itemView: T) {
            
            self.itemView = itemView
            
            super.init(frame: .zero)
            
            addSubview(itemView)
            addSubview(surfaceView)
            
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(didTap))
            surfaceView.addGestureRecognizer(tapGesture)
        }
        
        required init?(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func layoutSubviews() {
            super.layoutSubviews()
            
            itemView.frame = bounds
            surfaceView.frame = bounds
        }
        
        func setHandler(handler: @escaping () -> ()) {
            didTapHandler = handler
        }
        
        @objc private func didTap() {
            if let handler = didTapHandler {
                handler()
            }
        }
    }
    
}
