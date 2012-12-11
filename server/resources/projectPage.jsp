<%@ page import="jetbrains.buildServer.sharedResources.SharedResourcesPluginConstants" %>
<%@ include file="/include-internal.jsp" %>
<%@ page contentType="text/html;charset=UTF-8" language="java" %>

<jsp:useBean id="project" scope="request" type="jetbrains.buildServer.serverSide.SProject"/>
<jsp:useBean id="bean" scope="request" type="jetbrains.buildServer.sharedResources.pages.SharedResourcesBean"/>

<c:set var="PARAM_RESOURCE_NAME" value="<%=SharedResourcesPluginConstants.WEB.PARAM_RESOURCE_NAME%>"/>
<c:set var="PARAM_PROJECT_ID" value="<%=SharedResourcesPluginConstants.WEB.PARAM_PROJECT_ID%>"/>
<c:set var="PARAM_RESOURCE_QUOTA" value="<%=SharedResourcesPluginConstants.WEB.PARAM_RESOURCE_QUOTA%>"/>
<c:set var="PARAM_OLD_RESOURCE_NAME" value="<%=SharedResourcesPluginConstants.WEB.PARAM_OLD_RESOURCE_NAME%>"/>



<c:url var="url" value='editProject.html?projectId=${project.projectId}&tab=JetBrains.SharedResources'/>

<script type="text/javascript">
  //noinspection JSValidateTypes
  BS.ResourceDialog = OO.extend(BS.AbstractModalDialog, {
    attachedToRoot: false,
    editMode: false,
    currentResourceName: "",
    getContainer: function() {
      return $('resourceDialog');
    },

    showDialog: function() {
      this.showCentered();
      this.bindCtrlEnterHandler(this.submit.bind(this));
      this.editMode = false;
    },

    showEdit: function(resource_name, resource_quota) {
      this.editMode = true;
      this.currentResourceName = resource_name;
      $j('#resource_name').val(resource_name);
      if (resource_quota > 0) {
        $j('#use_quota').prop('checked', true);
        $j('#resource_quota').val(resource_quota);
      } else {
        $j('#use_quota').prop('checked', false);
        $j('#resource_quota').val(1);
      }

      this.toggleQuotaSwitch();
      this.showCentered();
      this.bindCtrlEnterHandler(this.submit.bind(this));
    },

    submit: function() {
      if (!this.validate()) return false;
      this.close();
      if (this.editMode) {
        BS.SharedResourcesActions.editResource(this.currentResourceName);
      } else {
        BS.SharedResourcesActions.addResource();
      }
      return false;
    },

    validate: function() {
      return true;
    },

    toggleQuotaSwitch: function() {
      var show = $j('#use_quota').is(':checked');
      if (show) {
        this.quoted = true;
        BS.Util.show("quota_row");
      } else {
        this.quoted = false;
        BS.Util.hide("quota_row");
      }
    },

    quoted: false
  });

  BS.SharedResourcesActions = {
    addUrl: window['base_uri'] + "/sharedResourcesAdd.html",
    addResource: function() {
      // if quota checkbox in unchecked, send no quota info
      if (BS.ResourceDialog.quoted) {
        BS.ajaxRequest(this.addUrl, {
          parameters: {'${PARAM_PROJECT_ID}':'${project.projectId}', '${PARAM_RESOURCE_NAME}':$j('#resource_name').val()},
          onSuccess: function() {
            window.location.reload();
          }
        });
      } else {
        BS.ajaxRequest(this.addUrl, {
          parameters: {'${PARAM_PROJECT_ID}':'${project.projectId}', '${PARAM_RESOURCE_NAME}':$j('#resource_name').val(), '${PARAM_RESOURCE_QUOTA}':$j('#resource_quota').val()},
          onSuccess: function() {
            window.location.reload();
          }
        });
      }
    },

    editUrl: window['base_uri'] + "/sharedResourcesEdit.html",
    editResource: function(old_resource_name) {
      if (BS.ResourceDialog.quoted) {
        BS.ajaxRequest(this.editUrl, {
          parameters: {
            '${PARAM_PROJECT_ID}':'${project.projectId}',
            '${PARAM_RESOURCE_NAME}':$j('#resource_name').val(),
            '${PARAM_RESOURCE_QUOTA}':$j('#resource_quota').val(),
            '${PARAM_OLD_RESOURCE_NAME}': old_resource_name},
          onSuccess: function() {
            window.location.reload();
          }
        });
      } else {
        BS.ajaxRequest(this.editUrl, {
          parameters: {
            '${PARAM_PROJECT_ID}':'${project.projectId}',
            '${PARAM_RESOURCE_NAME}':$j('#resource_name').val(),
            '${PARAM_OLD_RESOURCE_NAME}': old_resource_name},
          onSuccess: function() {
            window.location.reload();
          }
        });
      }
    },

    deleteUrl: window['base_uri'] + "/sharedResourcesDelete.html",
    deleteResource: function(resource_name) {
      BS.ajaxRequest(this.deleteUrl, {
        parameters: {'${PARAM_PROJECT_ID}':'${project.projectId}', '${PARAM_RESOURCE_NAME}': resource_name},
        onSuccess: function() {
          window.location.reload();
        }
      });
    }
  };
</script>

<div>
  <forms:addButton id="addNewResource" onclick="BS.ResourceDialog.showDialog(); return false">Add new resource</forms:addButton>
  <bs:dialog dialogId="resourceDialog" title="Resource Management" closeCommand="BS.ResourceDialog.close()">
    <table class="runnerFormTable">
      <tr>
        <th><label for="resource_name">Resource name:</label></th>
        <td>
          <forms:textField name="resource_name" id="resource_name" style="width: 100%" className="longField buildTypeParams" maxlength="40"/>
          <span class="smallNote">Specify the name of resource</span>
        </td>
      </tr>
      <tr>
        <th>Use quota:</th>
        <td>
          <forms:checkbox name="use_quota" id="use_quota" onclick="BS.ResourceDialog.toggleQuotaSwitch()" checked="false"/>
        </td>
      </tr>
      <tr id="quota_row" style="display: none">
        <th><label for="resource_quota">Resource quota:</label> </th>
        <td><forms:textField name="resource_quota" style="width: 25%" id="resource_quota" className="longField buildTypeParams" maxlength="3"/></td>
      </tr>
    </table>
    <div class="popupSaveButtonsBlock">
      <forms:cancel onclick="BS.ResourceDialog.close()" showdiscardchangesmessage="false"/>
      <forms:submit id="resourcesDialogSubmit" type="button" label="Add Resource" onclick="BS.ResourceDialog.submit()"/>
    </div>
  </bs:dialog>


  <c:choose>
    <c:when test="${not empty bean.resources}">
      <l:tableWithHighlighting style="width: 70%" className="parametersTable" mouseovertitle="Click to edit resource" highlightImmediately="true">
        <tr>
          <th>Resource name</th>
          <th style="width:40%" colspan="4">Quota</th>
        </tr>
        <c:forEach var="resource" items="${bean.resources}">
          <c:set var="onclick" value="BS.ResourceDialog.showEdit('${resource.name}', '${resource.quota}')"/>
          <c:set var="resourceName" value="${resource.name}"/>
          <c:set var="usage" value="${bean.usageMap[resourceName]}"/>
          <c:set var="used" value="${not empty usage}"/>
          <tr>
            <td class="name highlight" onclick="${onclick}"><c:out value="${resourceName}"/></td>
            <c:choose>
              <c:when test="${resource.infinite}">
                <td class="highlight" onclick="${onclick}">Infinite</td>
              </c:when>
              <c:otherwise>
                <td class="highlight" onclick="${onclick}"><c:out value="${resource.quota}"/></td>
              </c:otherwise>
            </c:choose>
            <c:choose>
              <c:when test="${used}">
                <td class="highlight" onclick="${onclick}">
                  <c:set var="usageSize" value="${fn:length(usage)}"/>
                  <bs:simplePopup controlId="usage${resourceName}"
                                  linkOpensPopup="true"
                                  popup_options="shift: {x: -150, y: 20}, className: 'quickLinksMenuPopup'">
                    <jsp:attribute name="content">
                      <div>
                        <ul class="menuList">
                          <c:forEach items="${usage}" var="usedInBuildType">
                            <l:li>
                              <bs:buildTypeLink buildType="${usedInBuildType}" style="padding-left:0px;"/>
                            </l:li>
                          </c:forEach>
                        </ul>
                      </div>
                    </jsp:attribute>
                    <jsp:body>Used in ${usageSize} build configurations</jsp:body>
                  </bs:simplePopup>
                </td>
              </c:when>
              <c:otherwise>
                <td class="highlight" onclick="${onclick}"> Resource is not used</td>
              </c:otherwise>
            </c:choose>
            <td class="edit highlight" onclick="${onclick}"><a href="#">edit</a></td>
            <td class="edit">
              <c:choose>
                <c:when test="${used}">
                  <%--<p>delete</p>--%> <%-- todo: tooltip ('can't delete used resource')--%>
                  <a href="#">delete</a>
                </c:when>
                <c:otherwise>
                  <a href="#" onclick="BS.SharedResourcesActions.deleteResource('${resource.name}')">delete</a>
                </c:otherwise>
              </c:choose>
            </td>
          </tr>
        </c:forEach>
      </l:tableWithHighlighting>
    </c:when>
    <c:otherwise>
      <p>
        <c:out value="There are no resources defined"/>
      </p>
    </c:otherwise>
  </c:choose>

</div>

