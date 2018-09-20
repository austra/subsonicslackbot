$stdout.sync = true
$LOAD_PATH << './lib'
require 'subsonic_bot'

run SubsonicBot::Web
