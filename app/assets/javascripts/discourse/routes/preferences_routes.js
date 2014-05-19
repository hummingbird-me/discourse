/**
  The common route stuff for a user's preference

  @class PreferencesRoute
  @extends Discourse.RestrictedUserRoute
  @namespace Discourse
  @module Discourse
**/
Discourse.PreferencesRoute = Discourse.RestrictedUserRoute.extend({
  model: function() {
    return this.modelFor('user');
  },

  setupController: function(controller, user) {
    controller.setProperties({ model: user, newNameInput: user.get('name') });
    this.controllerFor('user').set('indexStream', false);
  },

  actions: {
    showAvatarSelector: function() {
      var self = this,
          user = this.modelFor('user'),
          avatarSelector = this.controllerFor('avatar-selector');

      user.findAvatars().then(function (avatars) {
        avatarSelector.setProperties({
          username: user.get("username"),
          email: user.get("email"),
          avatar_type: user.get("avatar_type"),
          avatars: avatars
        });

        Discourse.Route.showModal(self, 'avatar-selector');
      });
    },

    updateLocalGravatar: function() { this.modelFor("user").updateGravatar(); },

    saveAvatarSelection: function() {
      var user = this.modelFor('user'),
          avatarSelector = this.controllerFor('avatar-selector');
      // sends the information to the server if it has changed
      if (avatarSelector.get('avatar_type') !== user.get('avatar_type')) {
        user.changeSelectedAvatar(avatarSelector.get('avatar_type'));
      }
      user.setProperties(avatarSelector.getProperties("avatar_type", "avatar_template"));
      avatarSelector.send('closeModal');
    },

    showProfileBackgroundFileSelector: function() {
      $("#profile-background-input").click();
    },
    clearProfileBackground: function() {
      this.modelFor('user').clearProfileBackground();
    }
  }
});

Discourse.PreferencesIndexRoute = Discourse.RestrictedUserRoute.extend({
  renderTemplate: function() {
    this.render('preferences', { into: 'user', outlet: 'userOutlet', controller: 'preferences' });
  }
});

/**
  The route for editing a user's "About Me" bio.

  @class PreferencesAboutRoute
  @extends Discourse.RestrictedUserRoute
  @namespace Discourse
  @module Discourse
**/
Discourse.PreferencesAboutRoute = Discourse.RestrictedUserRoute.extend({
  model: function() {
    return this.modelFor('user');
  },

  renderTemplate: function() {
    this.render({ into: 'user', outlet: 'userOutlet' });
  },

  setupController: function(controller, model) {
    controller.setProperties({ model: model, newBio: model.get('bio_raw') });
  },

  // A bit odd, but if we leave to /preferences we need to re-render that outlet
  deactivate: function() {
    this._super();
    this.render('preferences', { into: 'user', outlet: 'userOutlet', controller: 'preferences' });
  },

  actions: {
    changeAbout: function() {
      var route = this;
      var controller = route.controllerFor('preferences/about');

      controller.setProperties({ saving: true });
      return controller.get('model').save().then(function() {
        controller.set('saving', false);
        route.transitionTo('user.index');
      }, function() {
        // model failed to save
        controller.set('saving', false);
        alert(I18n.t('generic_error'));
      });
    }
  }

});

/**
  The route for editing a user's email

  @class PreferencesEmailRoute
  @extends Discourse.RestrictedUserRoute
  @namespace Discourse
  @module Discourse
**/
Discourse.PreferencesEmailRoute = Discourse.RestrictedUserRoute.extend({
  model: function() {
    return this.modelFor('user');
  },

  renderTemplate: function() {
    this.render({ into: 'user', outlet: 'userOutlet' });
  },

  setupController: function(controller, model) {
    controller.setProperties({ model: model, newEmail: model.get('email') });
  },

  // A bit odd, but if we leave to /preferences we need to re-render that outlet
  deactivate: function() {
    this._super();
    this.render('preferences', { into: 'user', outlet: 'userOutlet', controller: 'preferences' });
  }
});

/**
  The route for updating a user's username

  @class PreferencesUsernameRoute
  @extends Discourse.RestrictedUserRoute
  @namespace Discourse
  @module Discourse
**/
Discourse.PreferencesUsernameRoute = Discourse.RestrictedUserRoute.extend({
  model: function() {
    return this.modelFor('user');
  },

  renderTemplate: function() {
    return this.render({ into: 'user', outlet: 'userOutlet' });
  },

  // A bit odd, but if we leave to /preferences we need to re-render that outlet
  deactivate: function() {
    this._super();
    this.render('preferences', { into: 'user', outlet: 'userOutlet', controller: 'preferences' });
  },

  setupController: function(controller, user) {
    controller.setProperties({ model: user, newUsername: user.get('username') });
  }
});

/**
  The route for updating a user's title to one of their badges

  @class PreferencesBadgeTitleRoute
  @extends Discourse.RestrictedUserRoute
  @namespace Discourse
  @module Discourse
**/
Discourse.PreferencesBadgeTitleRoute = Discourse.RestrictedUserRoute.extend({
  model: function() {
    return Discourse.UserBadge.findByUsername(this.modelFor('user').get('username'));
  },

  renderTemplate: function() {
    return this.render('user/badge-title', { into: 'user', outlet: 'userOutlet' });
  },

  // A bit odd, but if we leave to /preferences we need to re-render that outlet
  deactivate: function() {
    this._super();
    this.render('preferences', { into: 'user', outlet: 'userOutlet', controller: 'preferences' });
  },

  setupController: function(controller, model) {
    controller.set('model', model);
    controller.set('user', this.modelFor('user'));

    model.forEach(function(userBadge) {
      if (userBadge.get('badge.name') === controller.get('user.title')) {
        controller.set('selectedUserBadgeId', userBadge.get('id'));
      }
    });
    if (!controller.get('selectedUserBadgeId') && controller.get('selectableUserBadges.length') > 0) {
      controller.set('selectedUserBadgeId', controller.get('selectableUserBadges')[0].get('id'));
    }
  }
});


