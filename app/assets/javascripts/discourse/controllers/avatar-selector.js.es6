/**
  The modal for selecting an avatar

  @class AvatarSelectorController
  @extends Discourse.Controller
  @namespace Discourse
  @uses Discourse.ModalFunctionality
  @module Discourse
**/
export default Discourse.Controller.extend(Discourse.ModalFunctionality, {

  allowAvatarUpload: Discourse.computed.setting('allow_uploaded_avatars'),

  actions: {
    useGeneratedAvatar: function() { this.set("avatar_type", 0); },
    useGravatar: function() { this.set("avatar_type", 1); },
    useUploadedAvatar: function() { this.set("avatar_type", 2); },
  },

  avatar_template: function() {
    switch(this.get("avatar_type")) {
      case 0: return this.get("avatars.generated");
      case 1: return this.get("avatars.gravatar.local") || this.get("avatars.gravatar.external");
      case 2: return this.get("avatars.uploaded");
    };
  }.property("avatars.generated", "avatars.gravatar.{local,external}", "avatars.uploaded", "avatar_type")

});
