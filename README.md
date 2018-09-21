# SubsonicSlackBot

A Sinatra app for Slack integration with Subsonic.  Typing keywords in Slack will create a Subsonic share for a given song or album.  That share is sent to the channel.  Optionally, if your Subsonic user is configured for Jukebox mode, it will begin to play for anyone logged in with that user, fun for synchronized music listening!

## Usage
Enter your trigger with no arguments in Slack for usage.

```
To use Subsonic Bot try typing:

subsonic song (optional: song name)
subsonic album (optional: artist)
subsonic artist (optional: artist)

subsonic song Evolution

Login here {your_subsonic_server} with the username {your_username} to listen in!
```

## Deployment

### Subsonic

Ensure your Subsonic server is accessible to the internet.  I use a noip dynamic DNS address.

Create a new user.  If you want to share this account with others (so you can all listen to the same songs), I recommend only selecting this permission for the user.

```
User is allowed to play files in jukebox mode
```

### Slack

Create an outgoing webhook.  You will need the token for your environment variables.  Use your Heroku address as the URL, with this endpoint:

```
https://some-cool-heroku-name-45711.herokuapp.com/subsonic
```

### Running Locally

```
Configure environment variables, see below
$ bundle install
$ foreman start
```

### Heroku

```
$ heroku create
$ git push heroku master
Configure environment variables, see below
```

### Envirnment Variables

You'll need to setup your environment variables, either locally in .env or on Heroku.

```
VERSION=1.14.0                        # Subsonic Api Version, this should be fine
CLIENT=slack                          # A unique string identifying the client application.
USERNAME=your_username                # Subsonic username
PASSWORD=your_password                # Subsonic password, this gets tokenized and send to your subsonic server with the salt.
SUBSONIC_SERVER=http://127.0.0.1:4040 # I use noip dynamic DNS and put that address on Heroku.
SLACK_TOKEN=my_slack_token            # An outgoing webhook token from slack.
```

For Heroku, you can use the gui, or for each setting:

```
$ heroku config:set SLACK_TOKEN=my_slack_token
```
