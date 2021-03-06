/*
 * Copyright 2000-2021 JetBrains s.r.o.
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

package jetbrains.buildServer.sharedResources.pages.beans;

import java.util.Collection;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;
import jetbrains.buildServer.serverSide.SProject;
import jetbrains.buildServer.sharedResources.model.resources.Resource;
import org.jetbrains.annotations.NotNull;

/**
 * Created with IntelliJ IDEA.
 *
 * @author Oleg Rybak (oleg.rybak@jetbrains.com)
 */
public class EditFeatureBean {

  @NotNull
  private final SProject myProject;

  @NotNull
  private final List<Resource> myAllResources;

  EditFeatureBean(@NotNull final SProject project,
                  @NotNull final List<Resource> allResources) {
    myProject = project;
    myAllResources = allResources;
  }

  @NotNull
  public SProject getProject() {
    return myProject;
  }

  @NotNull
  public Collection<Resource> getAllResources() {
    return myAllResources;
  }
}
