//
//  ChartTableViewCell.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 2/19/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import SwiftUI
import UIKit


public final class ChartTableViewCell: UITableViewCell {

    @IBOutlet public weak var supplementalChartContentView: ChartContainerView?
    
    @IBOutlet weak var chartContentView: ChartContainerView!

    @IBOutlet weak var mainStackView: UIStackView!
    
    @IBOutlet weak var titleStackView: UIStackView?
    
    @IBOutlet weak var titleLabel: UILabel?

    @IBOutlet weak var subtitleLabel: UILabel?
    
    var footerView: UIView?
    
    private var detailStackView: UIStackView?
    private var detailTitleLabel: UILabel?
    private var detailValueLabel: UILabel?
   
    @IBOutlet weak var rightArrowHint: UIImageView? {
        didSet {
            rightArrowHint?.isHidden = !doesNavigate
        }
    }
    
    public override func awakeFromNib() {
        titleStackView?.layoutMargins = UIEdgeInsets(top: 11, left: 16, bottom: 0, right: 16)
        titleStackView?.isLayoutMarginsRelativeArrangement = true

        if let mainStackView,
           let titleStackView
        {
            let detailTitleLabel = UILabel()
            detailTitleLabel.font = .systemFont(ofSize: 13, weight: .regular)
            detailTitleLabel.textColor = .secondaryLabel
            detailTitleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

            let detailValueLabel = UILabel()
            detailValueLabel.font = .systemFont(ofSize: 13, weight: .semibold)
            detailValueLabel.textColor = .secondaryLabel
            detailValueLabel.textAlignment = .right
            detailValueLabel.setContentHuggingPriority(.required, for: .horizontal)

            let detailStackView = UIStackView(
                arrangedSubviews: [
                    detailTitleLabel,
                    detailValueLabel
                ]
            )
            detailStackView.axis = .horizontal
            detailStackView.spacing = 4
            detailStackView.layoutMargins = UIEdgeInsets(
                top: 8,
                left: 16,
                bottom: 2,
                right: 16
            )
            detailStackView.isLayoutMarginsRelativeArrangement = true
            detailStackView.isHidden = true

            if let titleIndex = mainStackView.arrangedSubviews.firstIndex(
                of: titleStackView
            ) {
                mainStackView.insertArrangedSubview(
                    detailStackView,
                    at: titleIndex + 1
                )
            }

            self.detailStackView = detailStackView
            self.detailTitleLabel = detailTitleLabel
            self.detailValueLabel = detailValueLabel
        }
    }

    public var doesNavigate: Bool = true {
        didSet {
            rightArrowHint?.isHidden = !doesNavigate
        }
    }
    
    public override func prepareForReuse() {
        super.prepareForReuse()
        doesNavigate = true
        supplementalChartContentView?.isHidden = true
        supplementalChartContentView?.chartGenerator = nil
        chartContentView.chartGenerator = nil
        setDetailRow(title: nil, value: nil)
    }

    public func reloadChart() {
        supplementalChartContentView?.reloadChart()
        chartContentView.reloadChart()
    }
    
    public func setChartGenerator(generator: ((CGRect) -> UIView?)?) {
        chartContentView.chartGenerator = generator
    }
    
    public func setSupplementalChartGenerator(generator: ((CGRect) -> UIView?)?) {
        supplementalChartContentView?.chartGenerator = generator
        supplementalChartContentView?.isHidden = generator == nil
    }
    
    public func setTitleLabelText(label: String?) {
        titleLabel?.text = label
        titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
    }
    
    public func setTitleLabelAccessibilityIdentifier(_ value: String) {
        titleLabel?.accessibilityIdentifier = 
            "chartTitleText_\(value)_\(ChartsManager.xAxisAccessibilityIDs?.count ?? -1)"
    }
    
    public func setTitleLabelText(label: NSAttributedString?) {
        titleLabel?.attributedText = label
    }

    public func setDetailRow(
        title: String?,
        value: String?
    ) {
        detailTitleLabel?.text = title
        detailValueLabel?.text = value

        detailStackView?.isHidden =
            title == nil && value == nil
    }
    
    public func removeTitleLabelText() {
        titleLabel?.text?.removeAll()
        titleLabel?.attributedText = NSAttributedString(string: "")
    }
    
    public func setSubtitleLabel(label: NSAttributedString?) {
        subtitleLabel?.attributedText = label
    }
    
    public func removeSubtitleLabelText() {
        subtitleLabel?.text?.removeAll()
        subtitleLabel?.attributedText = NSAttributedString(string: "")
    }
    
    public func setTitleTextColor(color: UIColor) {
        titleLabel?.textColor = color
    }
    
    public func setSubtitleTextColor(color: UIColor) {
        subtitleLabel?.textColor = color
    }
    
    public func setAlpha(alpha: CGFloat) {
        titleLabel?.alpha = alpha
        subtitleLabel?.alpha = alpha
        detailStackView?.alpha = alpha
        footerView?.alpha = alpha
    }
    
    public func removeFooterView() {
        self.footerView?.removeFromSuperview()
        self.footerView = nil
    }

    private var footerHostingController: UIHostingController<AnyView>?
    
    public func setFooterView(content: (() -> some View)?) {
        if footerHostingController == nil {
            let controller = UIHostingController(rootView: AnyView(EmptyView()))
            controller.view.backgroundColor = .clear

            footerHostingController = controller
            footerView = controller.view

            mainStackView.addArrangedSubview(controller.view)

            controller.willMove(toParent: nil)
        }

        if let content = content?() {
            footerHostingController?.rootView = AnyView(content)
            footerView?.isHidden = false
            footerView?.invalidateIntrinsicContentSize()
            mainStackView.setNeedsLayout()
            mainStackView.layoutIfNeeded()
        } else {
            footerHostingController?.rootView = AnyView(EmptyView())
            footerView?.isHidden = true
        }
    }
}
