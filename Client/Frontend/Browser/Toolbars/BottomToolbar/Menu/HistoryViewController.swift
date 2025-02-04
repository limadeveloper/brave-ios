/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import Shared
import BraveShared
import Storage
import Data
import CoreData

private struct HistoryViewControllerUX {
  static let WelcomeScreenPadding: CGFloat = 15
  static let WelcomeScreenItemTextColor = UIColor.gray
  static let WelcomeScreenItemWidth = 170
}

class HistoryViewController: SiteTableViewController, ToolbarUrlActionsProtocol {
  weak var toolbarUrlActionsDelegate: ToolbarUrlActionsDelegate?
  fileprivate lazy var emptyStateOverlayView: UIView = self.createEmptyStateOverview()
  var frc: NSFetchedResultsController<History>?
  
    let isPrivateBrowsing: Bool
  
  init(isPrivateBrowsing: Bool) {
    self.isPrivateBrowsing = isPrivateBrowsing
    
    super.init(nibName: nil, bundle: nil)
    
    NotificationCenter.default.addObserver(self, selector: #selector(HistoryViewController.notificationReceived(_:)), name: .DynamicFontChanged, object: nil)
  }
  
  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  deinit {
    NotificationCenter.default.removeObserver(self, name: .DynamicFontChanged, object: nil)
  }
  
  override func viewDidLoad() {
    frc = History.frc()
    frc!.delegate = self
    super.viewDidLoad()
    self.tableView.accessibilityIdentifier = "History List"
    title = Strings.HistoryScreenTitle
    
    reloadData()
  }
  
  @objc func notificationReceived(_ notification: Notification) {
    switch notification.name {
    case .DynamicFontChanged:
      if emptyStateOverlayView.superview != nil {
        emptyStateOverlayView.removeFromSuperview()
      }
      emptyStateOverlayView = createEmptyStateOverview()
    default:
      // no need to do anything at all
      break
    }
  }
  
  override func reloadData() {
    guard let frc = frc else {
      return
    }
    
    do {
      try frc.performFetch()
    } catch let error as NSError {
      print(error.description)
    }
    
    tableView.reloadData()
    updateEmptyPanelState()
  }
  
  fileprivate func updateEmptyPanelState() {
    if frc?.fetchedObjects?.count == 0 {
      if self.emptyStateOverlayView.superview == nil {
        self.tableView.addSubview(self.emptyStateOverlayView)
        self.emptyStateOverlayView.snp.makeConstraints { make -> Void in
          make.edges.equalTo(self.tableView)
          make.size.equalTo(self.view)
        }
      }
    } else {
      self.emptyStateOverlayView.removeFromSuperview()
    }
  }
  
  fileprivate func createEmptyStateOverview() -> UIView {
    let overlayView = UIView()
    overlayView.backgroundColor = UIColor.white

    if #available(iOS 13.0, *) {
        overlayView.backgroundColor = .systemBackground
    }

    return overlayView
  }
  
  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = super.tableView(tableView, cellForRowAt: indexPath)
    configureCell(cell, atIndexPath: indexPath)
    return cell
  }
  
  func configureCell(_ _cell: UITableViewCell, atIndexPath indexPath: IndexPath) {
    guard let cell = _cell as? TwoLineTableViewCell else { return }
    
    if !tableView.isEditing {
      cell.gestureRecognizers?.forEach { cell.removeGestureRecognizer($0) }
      let lp = UILongPressGestureRecognizer(target: self, action: #selector(longPressedCell(_:)))
      cell.addGestureRecognizer(lp)
    }
    
    let site = frc!.object(at: indexPath)
    cell.backgroundColor = UIColor.clear
    cell.setLines(site.title, detailText: site.url)
    
    cell.imageView?.contentMode = .scaleAspectFit
    cell.imageView?.image = FaviconFetcher.defaultFavicon
    cell.imageView?.layer.borderColor = BraveUX.faviconBorderColor.cgColor
    cell.imageView?.layer.borderWidth = BraveUX.faviconBorderWidth
    cell.imageView?.layer.cornerRadius = 6
    cell.imageView?.layer.masksToBounds = true
    
    cell.imageView?.setIconMO(site.domain?.favicon, forURL: URL(string: site.url ?? ""))
  }
  
  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    let site = frc?.object(at: indexPath)
    
    if let u = site?.url, let url = URL(string: u) {
        dismiss(animated: true) {
            self.toolbarUrlActionsDelegate?.select(url: url, visitType: .typed)
        }
    }
    tableView.deselectRow(at: indexPath, animated: true)
  }
    
    @objc private func longPressedCell(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began,
            let cell = gesture.view as? UITableViewCell,
            let indexPath = tableView.indexPath(for: cell),
            let urlString = frc?.object(at: indexPath).url else {
                return
        }
        
        presentLongPressActions(gesture, urlString: urlString, isPrivateBrowsing: isPrivateBrowsing)
    }
  
  func numberOfSections(in tableView: UITableView) -> Int {
    return frc?.sections?.count ?? 0
  }
  
  func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    guard let sections = frc?.sections else { return nil }
    return sections.indices ~= section ? sections[section].name : nil
  }
  
  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    guard let sections = frc?.sections else { return 0 }
    return sections.indices ~= section ? sections[section].numberOfObjects : 0
  }
  
  func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
    return true
  }
  
  func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
    if editingStyle == UITableViewCell.EditingStyle.delete {
      if let obj = self.frc?.object(at: indexPath) {
        obj.delete()
      }
    }
  }
}

extension HistoryViewController: NSFetchedResultsControllerDelegate {
  func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
    tableView.beginUpdates()
  }
  
  func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
    tableView.endUpdates()
  }
  
  func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
    switch type {
    case .insert:
      let sectionIndexSet = IndexSet(integer: sectionIndex)
      self.tableView.insertSections(sectionIndexSet, with: .fade)
    case .delete:
      let sectionIndexSet = IndexSet(integer: sectionIndex)
      self.tableView.deleteSections(sectionIndexSet, with: .fade)
    default: break
    }
  }
  
  func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
    switch type {
    case .insert:
      if let indexPath = newIndexPath {
        tableView.insertRows(at: [indexPath], with: .automatic)
      }
    case .delete:
      if let indexPath = indexPath {
        tableView.deleteRows(at: [indexPath], with: .automatic)
      }
    case .update:
      if let indexPath = indexPath, let cell = tableView.cellForRow(at: indexPath) {
        configureCell(cell, atIndexPath: indexPath)
      }
    case .move:
      if let indexPath = indexPath {
        tableView.deleteRows(at: [indexPath], with: .automatic)
      }
      
      if let newIndexPath = newIndexPath {
        tableView.insertRows(at: [newIndexPath], with: .automatic)
      }
    @unknown default:
        assertionFailure()
    }
    updateEmptyPanelState()
  }
}
