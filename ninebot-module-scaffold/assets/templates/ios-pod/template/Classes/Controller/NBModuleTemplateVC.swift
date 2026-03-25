//
//  NBModuleTemplateVC.swift
//  NBModuleTemplate
//
//  Created by taowei on 2026/1/29.
//

import UIKit
import Common
import SnapKit
import NBBaseUIKit
import NBToolsKit
import NBRouter

/// 设置项搜索页主控制器
/// 这是一个基础模版，需要实现：
/// 1. 加载配置数据 (feature_search_list.json / vehicle_features_config.json)
/// 2. 实现搜索逻辑
/// 3. 实现路由跳转
class NBModuleTemplateVC: BaseViewController {

    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .singleLine
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 50
        tableView.tableFooterView = UIView()
        tableView.register(NBModuleTemplateResultCell.self, forCellReuseIdentifier: resultReuseId)
        return tableView
    }()

    private lazy var searchContainer: UIView = {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = UIColor.dy(.white, dark: .hex(0x1C1C1E))
        container.layer.cornerRadius = 12
        container.layer.borderWidth = 1
        container.layer.borderColor = UIColor.dy(.hex(0xE5E5E5), dark: .hex(0x3A3A3C)).cgColor
        container.clipsToBounds = true
        return container
    }()

    private lazy var searchIconView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.image = UIImage(systemName: "magnifyingglass")
        imageView.tintColor = UIColor.dy(.hex(0x8E8E93), dark: .hex(0x8E8E93))
        return imageView
    }()

    private lazy var searchField: UITextField = {
        let textField = UITextField()
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.borderStyle = .none
        textField.clearButtonMode = .whileEditing
        textField.returnKeyType = .search
        textField.font = .font16
        textField.delegate = self
        textField.addTarget(self, action: #selector(searchFieldDidChange(_:)), for: .editingChanged)

        let placeholderColor = UIColor.dy(.hex(0x8E8E93), dark: .hex(0x8E8E93))
        textField.attributedPlaceholder = NSAttributedString(
            string: "search_settings_item".lc,
            attributes: [.foregroundColor: placeholderColor, .font: textField.font as Any]
        )
        return textField
    }()

    // MARK: - 数据
    private let resultReuseId = "NBModuleTemplateResultCell"
    private var searchResults: [NBModuleTemplateSearchResultGroup] = []

    private var isSearching: Bool {
        let text = searchField.text ?? ""
        return !text.trimmingCharacters(in: .whitespaces).isEmpty
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.dy(.white, dark: .hex(0x1C1C1E))
        setupUI()
        setupTableView()

        // TODO: 在这里加载配置数据
        // 1. 加载 feature_search_list.json
        // 2. 加载 vehicle_features_config.json
        // 3. 解析数据并缓存
    }

    private func setupUI() {
        view.addSubview(searchContainer)
        searchContainer.addSubview(searchIconView)
        searchContainer.addSubview(searchField)

        NSLayoutConstraint.activate([
            searchContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            searchContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            searchContainer.heightAnchor.constraint(equalToConstant: 56),
            searchContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 15),

            searchIconView.leadingAnchor.constraint(equalTo: searchContainer.leadingAnchor, constant: 16),
            searchIconView.centerYAnchor.constraint(equalTo: searchContainer.centerYAnchor),
            searchIconView.widthAnchor.constraint(equalToConstant: 24),
            searchIconView.heightAnchor.constraint(equalToConstant: 24),

            searchField.leadingAnchor.constraint(equalTo: searchIconView.trailingAnchor, constant: 12),
            searchField.trailingAnchor.constraint(equalTo: searchContainer.trailingAnchor, constant: -16),
            searchField.centerYAnchor.constraint(equalTo: searchContainer.centerYAnchor),
            searchField.heightAnchor.constraint(equalToConstant: 36)
        ])
    }

    private func setupTableView() {
        view.addSubview(tableView)
        tableView.dataSource = self
        tableView.delegate = self

        tableView.snp.makeConstraints { make in
            make.top.equalTo(searchContainer.snp.bottom).offset(12)
            make.leading.trailing.equalToSuperview().inset(8)
            make.bottom.equalToSuperview().offset(-8)
        }
    }

    // MARK: - 搜索逻辑
    /// 执行搜索
    /// - Parameter text: 搜索关键字
    private func performSearch(with text: String) {
        guard !text.isEmpty else {
            searchResults.removeAll()
            tableView.reloadData()
            return
        }

        // TODO: 实现搜索逻辑
        // 1. 根据关键字匹配 title/tips/keywords
        // 2. 支持拼音匹配
        // 3. 分组显示结果
    }

    /// 跳转到目标页面
    /// - Parameters:
    ///   - page: 路由 URL
    ///   - capabilityId: 能力 ID
    private func navigateToPage(_ page: String, capabilityId: String? = nil) {
        do {
            var params: [String: Any] = [:]
            if let id = capabilityId {
                params["capabilityId"] = id
            }
            try NBRouter.shared.open(page, extraParams: params)
        } catch {
            printLog("Navigate to \(page) failed: \(error)")
        }
    }
}

// MARK: - UITextFieldDelegate
extension NBModuleTemplateVC: UITextFieldDelegate {
    @objc private func searchFieldDidChange(_ tf: UITextField) {
        let text = tf.text ?? ""
        if text.isEmpty {
            searchResults.removeAll()
            tableView.reloadData()
        } else {
            performSearch(with: text)
        }
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        performSearch(with: textField.text ?? "")
        textField.resignFirstResponder()
        return true
    }
}

// MARK: - UITableViewDataSource & UITableViewDelegate
extension NBModuleTemplateVC: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return searchResults.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let group = searchResults[section]
        return 1 + group.childCells.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: resultReuseId, for: indexPath) as! NBModuleTemplateResultCell
        let group = searchResults[indexPath.section]

        if indexPath.row == 0 {
            cell.configure(with: group.topLevelCell, keyword: searchField.text ?? "", isFirstRow: indexPath.section == 0 && indexPath.row == 0)
        } else {
            let childIndex = indexPath.row - 1
            if childIndex < group.childCells.count {
                cell.configure(with: group.childCells[childIndex], keyword: searchField.text ?? "", isFirstRow: false)
            }
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let group = searchResults[indexPath.section]
        let cell: NBModuleTemplateSearchResultCell

        if indexPath.row == 0 {
            cell = group.topLevelCell
        } else {
            let childIndex = indexPath.row - 1
            guard childIndex < group.childCells.count else { return }
            cell = group.childCells[childIndex]
        }

        // TODO: 处理点击事件
        // 1. 检查功能是否可用
        // 2. 获取跳转页面
        // 3. 执行跳转
        printLog("Selected: \(cell.capability_id) - \(cell.feature?.title ?? cell.item.title)")
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let cell = cell as? NBModuleTemplateResultCell else { return }

        let sections = tableView.numberOfSections
        let isFirstSection = indexPath.section == 0
        let isLastSection = indexPath.section == sections - 1
        let isFirstRow = indexPath.row == 0
        let isLastRowInSection = indexPath.row == tableView.numberOfRows(inSection: indexPath.section) - 1

        if sections <= 1 {
            cell.applyRoundedCorners(top: isFirstRow, bottom: isLastRowInSection)
        } else {
            if isFirstSection {
                cell.applyRoundedCorners(top: isFirstRow, bottom: false)
            } else if isLastSection {
                cell.applyRoundedCorners(top: false, bottom: isLastRowInSection)
            } else {
                cell.applyRoundedCorners(top: false, bottom: false)
            }
        }

        // 首行不显示分割线
        if isFirstSection && isFirstRow {
            cell.setSeparatorHidden(true)
        } else {
            cell.setSeparatorHidden(false)
        }
    }
}
