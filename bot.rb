require 'cinch'
require './spyrungame/lib/cinch/plugins/spyrungame'

bot = Cinch::Bot.new do

  configure do |c|
    c.nick            = "spyrunbot"
    c.server          = "chat.freenode.net"
    c.channels        = ["#playspyfall"]
    c.verbose         = true
    c.plugins.plugins = [
        Cinch::Plugins::Spyrungame
    ]
    c.plugins.options[Cinch::Plugins::Spyrungame] = {
        :mods     => ["contig-mod"],
        :channel  => "#playspyfall",
#        :settings => "settings.yml"
    }
  end

end

bot.start
