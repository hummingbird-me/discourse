/**
  This view handles the avatar selection interface

  @class AvatarSelectorView
  @extends Discourse.ModalBodyView
  @namespace Discourse
  @module Discourse
**/
Discourse.AvatarSelectorView = Discourse.ModalBodyView.extend({
  templateName: 'modal/avatar_selector',
  classNames: ['avatar-selector'],
  title: I18n.t('user.change_avatar.title'),
  uploading: false,
  uploadProgress: 0,
  imageIsNotASquare : false,

  didInsertElement: function() {
    var self = this,
        $upload = $("#avatar-input");

    this._super();

    // simulate a click on the hidden file input when clicking on our fake file input
    $("#fake-avatar-input").on("click", function(e) {
      // do *NOT* use the cached `$upload` variable, because fileupload is cloning & replacing the input
      // cf. https://github.com/blueimp/jQuery-File-Upload/wiki/Frequently-Asked-Questions#why-is-the-file-input-field-cloned-and-replaced-after-each-selection
      $("#avatar-input").click();
      e.preventDefault();
    });

    // define the upload endpoint
    $upload.fileupload({
      url: Discourse.getURL("/users/" + this.get("controller.username") + "/preferences/user_image"),
      dataType: "json",
      fileInput: $upload,
      formData: { user_image_type: "avatar" }
    });

    // when a file has been selected
    $upload.on('fileuploadsubmit', function (e, data) {
      var result = Discourse.Utilities.validateUploadedFiles(data.files, true);
      self.setProperties({
        uploadProgress: 0,
        uploading: result,
        imageIsNotASquare: false
      });
      return result;
    });

    // when there is a progression for the upload
    $upload.on("fileuploadprogressall", function (e, data) {
      var progress = parseInt(data.loaded / data.total * 100, 10);
      self.set("uploadProgress", progress);
    });

    // when the upload is successful
    $upload.on("fileuploaddone", function (e, data) {
      // make sure we have a template
      if (data.result.template) {
        Em.run.next(function () {
          // indicates the users is using an uploaded avatar
          self.get("controller").set("avatar_type", 2);
          self.get("controller").set("avatars.uploaded", data.result.template);
          // display a warning whenever the image is not a square
          self.set("imageIsNotASquare", data.result.width !== data.result.height);
        });
      } else {
        bootbox.alert(I18n.t('post.errors.upload'));
      }
    });

    // when there has been an error with the upload
    $upload.on("fileuploadfail", function (e, data) {
      Discourse.Utilities.displayErrorForUpload(data);
    });

    // when the upload is done
    $upload.on("fileuploadalways", function () {
      self.setProperties({ uploading: false, uploadProgress: 0 });
    });
  },

  willDestroyElement: function() {
    $("#fake-avatar-input").off("click");
    $("#avatar-input").fileupload("destroy");
  },

  // *HACK* used to select the proper radio button
  selectedChanged: function() {
    var self = this;
    Em.run.next(function() {
      $('input:radio[name="avatar"]').val([self.get('controller.avatar_type')]);
    });
  }.observes('controller.avatar_type'),

  uploadButtonText: function() {
    return this.get("uploading") ? I18n.t("uploading") : I18n.t("upload");
  }.property("uploading")

});
