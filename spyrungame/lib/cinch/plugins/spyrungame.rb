require 'cinch'

require_relative 'game'

module Cinch
  module Plugins


    class Spyrungame
      include Cinch::Plugin

      def initialize(*args)
        super
        @active_game = Game.new
        @channel_name = config[:channel]
      end

      match /join/i, :method => :join
      match /leave/i, :method => :leave
      match /start/i, :method => :start
      match /locations/i, :method => :send_private_locations
      match /vote (.+)/i, :method=>:vote
      match /unvote/i, :method=>:unvote
      match /guess (.+)/i, :method=>:guess_location
      match /help/i, :method=>:help
      match /setlocations? (.*)/i, :method =>:set_locations
      match /addlocations? (.*)/i, :method =>:add_locations
      match /removelocations? (.*)/i, :method =>:remove_locations


      def help(m)
        User(m.user).send '!join to join a game'
        User(m.user).send '!leave to leave a game'
        User(m.user).send '!start to start a game'
        User(m.user).send '!vote [target] to secretly vote for a player as spy'
        User(m.user).send '!unvote to secretly remove your vote'
        User(m.user).send '!guess [location] to guess a location (Spy only)'
        User(m.user).send '!locations to view possible locations'
        User(m.user).send '!help to see this help screen'
        User(m.user).send '!setlocations [location1, location2, ...] to set new locations'
        User(m.user).send '!addlocations [location1, location2, ...] to add new locations'
        User(m.user).send '!removelocations [location1, location2, ...] to remove locations'
      end

      def join(m)
        if Channel(@channel_name).has_user?(m.user)
          if @active_game.started
            User(m.user).send 'Game already started'
          else
            @active_game.add_user(m.user)
            Channel(@channel_name).send " #{m.user.nick} joined. Game now has #{@active_game.players_joined} player(s)."
          end
        else
          User(m.user).send "You need to be in #{@channel_name}."
        end
      end

      def leave(m)
        if Channel(@channel_name).has_user?(m.user)
          if @active_game.started
            User(m.user).send 'Game already started'
          else
            @active_game.remove_user(m.user)
            Channel(@channel_name).send "#{m.user.nick} left. Game now has #{@active_game.players_joined} player(s)."
          end
        end
      end

      def start(m)
        if @active_game.started
          User(m.user).send 'Game has started already'
        elsif @active_game.players_joined<3
          User(m.user).send 'Need 3 or more players to start'
        elsif @active_game.locations.length<3
          User(m.user).send 'Need at least 3 locations to start'
        else
          @active_game.setup_game
          Channel(@channel_name).send "Game has started with #{@active_game.playing_user_names.join(', ')}."
          Channel(@channel_name).send "#{@active_game.votes_needed} votes are needed to accuse a spy."

          self.send_locations

          @active_game.user_hash.values.each do |single_user|
            if single_user == @active_game.spy_user
              User(single_user).send 'You are the spy! Try to find the secret location.'
            else
              User(single_user).send "The location of interest is #{@active_game.actual_location}. Try to find the spy."
            end
          end

        end
      end

      def send_private_locations(m)
        if @active_game.player_during_main_phase?(m.user.nick)
          all_locations=@active_game.locations.join(', ')
          User(m.user).send "Locations being used: #{all_locations}"
        end
      end

      def send_locations
        all_locations=@active_game.locations.join(', ')
        Channel(@channel_name).send "Locations being used: #{all_locations}"
      end

      def vote(m, target_name)
        if @active_game.player_during_main_phase?(m.user.nick)
          if @active_game.playing_user_names.include?(target_name)
            @active_game.votes[m.user.nick]=target_name

            if @active_game.enough_votes_for_target?(target_name)
              do_end_game(target_name)
            else
              User(m.user).send "Your vote is now set for \"#{@active_game.votes[m.user.nick]}\""
            end
          else
            User(m.user).send "Don't understand player \"#{target_name}\""
          end
        end
      end

      def unvote(m)
        if @active_game.player_during_main_phase?(m.user.nick)
         @active_game.votes.delete(m.user.nick)
          User(m.user).send 'Vote removed'
        end
      end


      def do_end_game(accused_spy_name)
        @active_game.phase=:end
        spy_name=@active_game.spy_user.nick
        self.display_roles
        accusers=[]
        end_game_message="Player #{accused_spy_name} is accused of being a spy!\nAccusers: "
        @active_game.votes.each do |player_name, player_target_name|
          if player_target_name==accused_spy_name
            accusers << player_name
          end
        end
        end_game_message << accusers.join(', ')
        Channel(@channel_name).send end_game_message

        if spy_name==accused_spy_name
          Channel(@channel_name).send "\nThe accusers are correct! Agents win!"
          self.reset_game
        else
          Channel(@channel_name).send "\nThe accusers are wrong! The spy was #{spy_name}."
          Channel(@channel_name).send "\n#{spy_name}, make a guess for the location."
        end
      end

      def display_roles
        spy_name=@active_game.spy_user.nick
        agent_names=@active_game.playing_user_names.reject {|name| name==spy_name}
        Channel(@channel_name).send '=================================================='
        Channel(@channel_name).send "Spy: #{spy_name}, Agents: #{agent_names.join(', ')}"
      end

      def guess_location(m,guessed_location)
        if m.user == @active_game.spy_user
          if @active_game.locations.any? { |s| s.casecmp(guessed_location)==0}
            spy_message=''
            agents_message=''
            spy_name=@active_game.spy_user.nick
            if @active_game.phase==:main
              self.display_roles
              spy_message= "(#{spy_name}) "
              agents_message = ' Agents win!'
            end
            @active_game.phase=:end#end game when location is guessed

            if @active_game.actual_location.downcase == guessed_location.downcase
              Channel(@channel_name).send "The spy #{spy_message}guessed the location #{guessed_location} correctly and wins!"
            else
              Channel(@channel_name).send "The spy #{spy_message}guessed the location #{guessed_location} but was wrong!#{agents_message}"
              Channel(@channel_name).send "\n(The correct location was #{@active_game.actual_location}.)"
            end
            self.reset_game
          else
            User(m.user).send "Don't recognize #{guessed_location}. Please guess again or use !locations"
          end

        elsif @active_game.user_hash.keys.include?(m.user.nick)
          User(m.user).send 'Only the spy may guess the location.'
        end
      end

      def reset_game
        old_locations=@active_game.locations
        Channel(@channel_name).send '=================================================='
        @active_game=Game.new
        @active_game.locations=old_locations
      end

      def set_locations(m, location_string)
        new_locations=location_string.split(',')
        @active_game.locations=[]
        new_locations.each do |single_location|
          single_location.strip!
          @active_game.locations.push(single_location)
        end
        User(m.user).send "Using #{new_locations.length} location(s)"
        self.send_locations
      end

      def add_locations(m, location_string)
        new_locations=location_string.split(',')
        new_locations.each do |single_location|
          single_location.strip!
          @active_game.locations.push(single_location)
        end
        User(m.user).send "Added #{new_locations.length} location(s)"
        self.send_locations
      end

      def remove_locations(m, location_string)
        new_locations=location_string.split(',')
        lower_game_locations=@active_game.locations.map{ |a| a.downcase }
        new_locations.each do |single_location|
          single_location.strip!
          if lower_game_locations.include?(single_location.downcase)
              @active_game.locations.delete_if{|my_location|single_location.downcase==my_location.downcase}
          else
              User(m.user).send "Not in list: location #{single_location}"
              new_locations.delete(single_location)
          end
        end
        User(m.user).send "Removed #{new_locations.length} location(s)"
        self.send_locations
      end

    end
  end
end