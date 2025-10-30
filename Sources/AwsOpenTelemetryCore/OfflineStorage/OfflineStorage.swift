/*
 * Copyright Amazon.com, Inc. or its affiliates.
 *
 * Licensed under the Apache License, Version 2.0 (the "License").
 * You may not use this file except in compliance with the License.
 * A copy of the License is located at
 *
 *  http://aws.amazon.com/apache2.0
 *
 * or in the "license" file accompanying this file. This file is distributed
 * on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
 * express or implied. See the License for the specific language governing
 * permissions and limitations under the License.
 */

import Foundation
import CoreData

/// Basic offline storage module with CRUD operations and storage limits
public class OfflineStorage {
  private let maxStorageItems = 1000
  private lazy var persistentContainer: NSPersistentContainer = {
    let container = NSPersistentContainer(name: "OfflineStorage")

    // Ensure data stays local and is not synced to iCloud
    let storeDescription = container.persistentStoreDescriptions.first
    storeDescription?.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
    storeDescription?.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
    storeDescription?.setOption("NONE" as NSString, forKey: "NSPersistentStoreUbiquitousContentNameKey")

    container.loadPersistentStores { _, error in
      if let error {
        AwsInternalLogger.error("CoreData error: \(error)")
      }
    }
    return container
  }()

  private var context: NSManagedObjectContext {
    return persistentContainer.viewContext
  }

  public init() {}

  /// Create a new hang record
  public func createHangRecord(startTime: Date, id: String = UUID().uuidString) -> Bool {
    enforceStorageLimit()

    let entity = NSEntityDescription.entity(forEntityName: "HangRecord", in: context)!
    let hangRecord = NSManagedObject(entity: entity, insertInto: context)

    hangRecord.setValue(id, forKey: "id")
    hangRecord.setValue(startTime, forKey: "startTime")
    hangRecord.setValue(Date(), forKey: "createdAt")

    return saveContext()
  }

  /// Read hang record by ID
  public func readHangRecord(id: String) -> (startTime: Date, createdAt: Date)? {
    let request = NSFetchRequest<NSManagedObject>(entityName: "HangRecord")
    request.predicate = NSPredicate(format: "id == %@", id)
    request.fetchLimit = 1

    do {
      let results = try context.fetch(request)
      guard let record = results.first,
            let startTime = record.value(forKey: "startTime") as? Date,
            let createdAt = record.value(forKey: "createdAt") as? Date else {
        return nil
      }
      return (startTime: startTime, createdAt: createdAt)
    } catch {
      AwsInternalLogger.error("Failed to read hang record: \(error)")
      return nil
    }
  }

  /// Update hang record with end time
  public func updateHangRecord(id: String, endTime: Date) -> Bool {
    let request = NSFetchRequest<NSManagedObject>(entityName: "HangRecord")
    request.predicate = NSPredicate(format: "id == %@", id)
    request.fetchLimit = 1

    do {
      let results = try context.fetch(request)
      guard let record = results.first else { return false }

      record.setValue(endTime, forKey: "endTime")
      return saveContext()
    } catch {
      AwsInternalLogger.error("Failed to update hang record: \(error)")
      return false
    }
  }

  /// Delete hang record by ID
  public func deleteHangRecord(id: String) -> Bool {
    let request = NSFetchRequest<NSManagedObject>(entityName: "HangRecord")
    request.predicate = NSPredicate(format: "id == %@", id)

    do {
      let results = try context.fetch(request)
      for record in results {
        context.delete(record)
      }
      return saveContext()
    } catch {
      AwsInternalLogger.error("Failed to delete hang record: \(error)")
      return false
    }
  }

  /// Get all unresolved hang records (no end time)
  public func getUnresolvedHangs() -> [(id: String, startTime: Date, createdAt: Date)] {
    let request = NSFetchRequest<NSManagedObject>(entityName: "HangRecord")
    request.predicate = NSPredicate(format: "endTime == nil")

    do {
      let results = try context.fetch(request)
      return results.compactMap { record in
        guard let id = record.value(forKey: "id") as? String,
              let startTime = record.value(forKey: "startTime") as? Date,
              let createdAt = record.value(forKey: "createdAt") as? Date else {
          return nil
        }
        return (id: id, startTime: startTime, createdAt: createdAt)
      }
    } catch {
      AwsInternalLogger.error("Failed to get unresolved hangs: \(error)")
      return []
    }
  }

  private func enforceStorageLimit() {
    let request = NSFetchRequest<NSManagedObject>(entityName: "HangRecord")
    request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]

    do {
      let results = try context.fetch(request)
      if results.count >= maxStorageItems {
        let itemsToDelete = results.prefix(results.count - maxStorageItems + 1)
        for item in itemsToDelete {
          context.delete(item)
        }
        _ = saveContext()
      }
    } catch {
      AwsInternalLogger.error("Failed to enforce storage limit: \(error)")
    }
  }

  private func saveContext() -> Bool {
    do {
      try context.save()
      return true
    } catch {
      AwsInternalLogger.error("Failed to save context: \(error)")
      return false
    }
  }
}
