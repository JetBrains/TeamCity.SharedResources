/*
 * Copyright 2000-2013 JetBrains s.r.o.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package jetbrains.buildServer.sharedResources.server.runtime;

import jetbrains.buildServer.serverSide.BuildPromotionEx;
import jetbrains.buildServer.serverSide.RunningBuildEx;
import jetbrains.buildServer.serverSide.buildDistribution.BuildPromotionInfo;
import jetbrains.buildServer.serverSide.buildDistribution.QueuedBuildInfo;
import jetbrains.buildServer.serverSide.buildDistribution.RunningBuildInfo;
import jetbrains.buildServer.sharedResources.model.Lock;
import jetbrains.buildServer.sharedResources.model.TakenLock;
import jetbrains.buildServer.sharedResources.model.resources.CustomResource;
import jetbrains.buildServer.sharedResources.model.resources.QuotedResource;
import jetbrains.buildServer.sharedResources.model.resources.Resource;
import jetbrains.buildServer.sharedResources.model.resources.ResourceType;
import jetbrains.buildServer.sharedResources.server.feature.Locks;
import jetbrains.buildServer.sharedResources.server.feature.Resources;
import org.jetbrains.annotations.NotNull;

import java.util.*;

/**
 * @author Oleg Rybak (oleg.rybak@jetbrains.com)
 */
public class TakenLocksImpl implements TakenLocks {

  @NotNull
  private final Locks myLocks;

  @NotNull
  private final Resources myResources;

  @NotNull
  private final LocksStorage myLocksStorage;

  public TakenLocksImpl(@NotNull final Locks locks,
                        @NotNull final Resources resources,
                        @NotNull final LocksStorage locksStorage) {
    myLocks = locks;
    myResources = resources;
    myLocksStorage = locksStorage;
  }

  @NotNull
  @Override
  public Map<String, TakenLock> collectTakenLocks(@NotNull final String projectId,
                                                  @NotNull final Collection<RunningBuildInfo> runningBuilds,
                                                  @NotNull final Collection<QueuedBuildInfo> queuedBuilds) {
    final Map<String, TakenLock> result = new HashMap<String, TakenLock>();
    for (RunningBuildInfo runningBuildInfo: runningBuilds) {
      BuildPromotionEx bpEx = (BuildPromotionEx)runningBuildInfo.getBuildPromotionInfo();
      if (projectId.equals(bpEx.getProjectId())) {
        Collection<Lock> locks;
        RunningBuildEx rbEx = (RunningBuildEx)runningBuildInfo;
        if (myLocksStorage.locksStored(rbEx)) {
          locks = myLocksStorage.load(rbEx).values();
        } else {
          locks = myLocks.fromBuildPromotion(bpEx);
        }
        addToTakenLocks(result, bpEx, locks);
      }
    }
    for (QueuedBuildInfo info: queuedBuilds) {
      BuildPromotionEx bpEx = (BuildPromotionEx)info.getBuildPromotionInfo();
      if (projectId.equals(bpEx.getProjectId())) {
        Collection<Lock> locks = myLocks.fromBuildPromotion(bpEx);
        addToTakenLocks(result, bpEx, locks);
      }
    }
    return result;
  }

  private void addToTakenLocks(@NotNull final Map<String, TakenLock> takenLocks,
                               @NotNull final BuildPromotionInfo bpInfo,
                               @NotNull final Collection<Lock> locks) {
    for (Lock lock: locks) {
      TakenLock takenLock = takenLocks.get(lock.getName());
      if (takenLock == null) {
        takenLock = new TakenLock();
        takenLocks.put(lock.getName(), takenLock);
      }
      takenLock.addLock(bpInfo, lock);
    }
  }

  @NotNull
  @Override
  public Collection<Lock> getUnavailableLocks(@NotNull Collection<Lock> locksToTake,
                                              @NotNull Map<String, TakenLock> takenLocks,
                                              @NotNull String projectId) {
    final Map<String, Resource> resources = myResources.asMap(projectId);
    final Collection<Lock> result = new ArrayList<Lock>();
    for (Lock lock : locksToTake) {
      final TakenLock takenLock = takenLocks.get(lock.getName());
      if (takenLock != null) {
        final Resource resource = resources.get(lock.getName());
        if (resource != null && !checkAgainstResource(lock, takenLocks, resource))  {
          result.add(lock);
        }
      }
    }
    return result;
  }

  private boolean checkAgainstResource(@NotNull final Lock lock,
                                       @NotNull final Map<String, TakenLock> takenLocks,
                                       @NotNull final Resource resource) {
    boolean result = true;
    if (ResourceType.QUOTED.equals(resource.getType())) {
      result = checkAgainstQuotedResource(lock, takenLocks, (QuotedResource) resource);
    } else if (ResourceType.CUSTOM.equals(resource.getType())) {
      result = checkAgainstCustomResource(lock, takenLocks, (CustomResource) resource);
    }
    return result;
  }

  private boolean checkAgainstCustomResource(@NotNull final Lock lock,
                                             @NotNull final Map<String, TakenLock> takenLocks,
                                             @NotNull final CustomResource resource) {
    boolean result = true;
    // what type of lock do we have
    // write with value -> specific
    // write            -> all
    // read             -> any
    final TakenLock takenLock = takenLocks.get(lock.getName());
    switch (lock.getType()) {
      case READ:   // check at least one value is available
        // check for unique writeLocks
        Map<BuildPromotionInfo, String> writeLocks = takenLock.getWriteLocks();
        for (String str: writeLocks.values()) {
          if ("".equals(str)) {
            // we have 'ALL' write lock
            result = false;
            break;
          }
        }
        if (result) {
          // check for any available values
          if (resource.getValues().size() <= takenLock.getReadLocks().size() + takenLock.getWriteLocks().size()) {
            // quota exceeded
            result = false;
            break;
          }
        }
        break;
      case WRITE:
        if ("".equals(lock.getValue())) {
          // 'ALL' case
          if (takenLock.hasReadLocks() || takenLock.hasWriteLocks()) {
            result = false;
            break;
          }
        } else {
          // 'SPECIFIC' case
          final String requiredValue = lock.getValue();
          final Set<String> takenValues = new HashSet<String>();
          takenValues.addAll(takenLock.getReadLocks().values());
          takenValues.addAll(takenLock.getWriteLocks().values());
          if (takenValues.contains(requiredValue)) {
            // value was already taken
            result = false;
            break;
          }
        }
        break;
    }
    return result;
  }

  private boolean checkAgainstQuotedResource(@NotNull final Lock lock,
                                             @NotNull final Map<String, TakenLock> takenLocks,
                                             @NotNull final QuotedResource resource) {
    boolean result = true;
    final TakenLock takenLock = takenLocks.get(lock.getName());
    switch (lock.getType())  {
      case READ:
        // 1) Check that no write lock exists
        if (takenLock.hasWriteLocks()) {
          result = false;
          break;
        }
        if (!resource.isInfinite()) {
          if (takenLock.getReadLocks().size() >= resource.getQuota()) {
            result = false;
            break;
          }
        }
        break;
      case WRITE:
        if (takenLock.hasReadLocks() || takenLock.hasWriteLocks()) { // if anyone is accessing the resource
          result = false;
        }
    }
    return result;
  }
}