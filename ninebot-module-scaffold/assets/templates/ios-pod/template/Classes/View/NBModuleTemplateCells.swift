//
//  NBModuleTemplateCells.swift
//  NBModuleTemplate
//
//  Created by taowei on 2026/1/30.
//

import UIKit
import SnapKit
import NBBaseUIKit
import Common

/// 搜索结果 Cell
final class NBModuleTemplateResultCell: UITableViewCell {

    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    private let tipsLabel = UILabel()
    private let arrowImageView = UIImageView()
    private let separatorView = UIView()
    var containerView: UIView!

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupSubviews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupSubviews()
    }

    private func setupSubviews() {
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        containerView = UIView()
        containerView.backgroundColor = UIColor.dy(.white, dark: .hex(0x1C1C1E))
        containerView.layer.cornerRadius = 0
        containerView.clipsToBounds = true
        contentView.addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.bottom.equalToSuperview()
            make.height.greaterThanOrEqualTo(56)
        }

        // Icon
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.backgroundColor = UIColor.dy(.hex(0xF5F5F5), dark: .hex(0x2C2C2E))
        containerView.addSubview(iconImageView)
        iconImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.top.equalToSuperview().offset(16)
            make.width.height.equalTo(24)
        }

        // Title
        titleLabel.font = .font16
        titleLabel.textColor = .titleColor
        titleLabel.numberOfLines = 1
        containerView.addSubview(titleLabel)

        // Tips
        tipsLabel.font = .font14
        tipsLabel.textColor = .subTitleColor
        tipsLabel.numberOfLines = 2
        containerView.addSubview(tipsLabel)

        // Arrow
        arrowImageView.image = UIImage(systemName: "chevron.right")
        arrowImageView.tintColor = .subTitleColor
        arrowImageView.contentMode = .scaleAspectFit
        containerView.addSubview(arrowImageView)
        arrowImageView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-12)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(16)
        }

        // Separator
        separatorView.backgroundColor = UIColor.dy(.lightGray, dark: .hex(0x3A3A3C)).withAlphaComponent(0.3)
        containerView.addSubview(separatorView)
    }

    /// 配置 Cell
    /// - Parameters:
    ///   - cell: 数据模型
    ///   - keyword: 搜索关键字（用于高亮）
    ///   - isFirstRow: 是否是首行
    func configure(with cell: NBModuleTemplateSearchResultCell, keyword: String = "", isFirstRow: Bool = false) {
        separatorView.isHidden = isFirstRow

        // 设置标题
        titleLabel.text = cell.feature?.title ?? cell.item.title

        // 设置副标题
        tipsLabel.text = cell.tips
        tipsLabel.isHidden = cell.tips == nil || cell.tips?.isEmpty == true

        // 设置图标
        if let icon = cell.feature?.icon, !icon.isEmpty {
            iconImageView.isHidden = false
            // TODO: 加载图标资源
            // 优先从动态包加载，否则使用 bundle 资源
        } else {
            iconImageView.isHidden = true
        }

        // 布局调整
        if iconImageView.isHidden {
            titleLabel.snp.remakeConstraints { make in
                make.leading.equalToSuperview().offset(16)
                make.top.equalToSuperview().offset(16)
                make.trailing.equalTo(arrowImageView.snp.leading).offset(-12)
                make.height.equalTo(21)
            }
        } else {
            titleLabel.snp.remakeConstraints { make in
                make.leading.equalTo(iconImageView.snp.trailing).offset(12)
                make.top.equalToSuperview().offset(16)
                make.trailing.equalTo(arrowImageView.snp.leading).offset(-12)
                make.height.equalTo(21)
            }
        }

        if !tipsLabel.isHidden {
            tipsLabel.snp.remakeConstraints { make in
                make.leading.equalTo(titleLabel.snp.leading)
                make.trailing.equalTo(arrowImageView.snp.leading).offset(-12)
                make.top.equalTo(titleLabel.snp.bottom).offset(4)
                make.bottom.equalToSuperview().offset(-16)
            }
        } else {
            tipsLabel.snp.remakeConstraints { make in
                make.leading.equalTo(titleLabel.snp.leading)
                make.trailing.equalTo(arrowImageView.snp.leading).offset(-12)
                make.top.equalTo(titleLabel.snp.bottom).offset(4)
                make.bottom.equalToSuperview().offset(-16)
            }
        }
    }

    /// 应用圆角
    func applyRoundedCorners(top: Bool, bottom: Bool, radius: CGFloat = 12) {
        var corners: CACornerMask = []
        if top {
            corners.insert(.layerMinXMinYCorner)
            corners.insert(.layerMaxXMinYCorner)
        }
        if bottom {
            corners.insert(.layerMinXMaxYCorner)
            corners.insert(.layerMaxXMaxYCorner)
        }
        containerView.layer.cornerRadius = corners.isEmpty ? 0 : radius
        containerView.layer.maskedCorners = corners
    }

    func setSeparatorHidden(_ hidden: Bool) {
        separatorView.isHidden = hidden
    }
}
