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
      match /ask (.+?) (.*)/i, :method => :ask
      match /answer (.+)/i, :method => :answer
      match /answeredby (.*)/i, :method => :answeredby
      match /review/i, :method => :review
      match /remaining/i, :method => :remaining

#      match /clear (.+)/i, :method => :clear
#      match /clearlist/i, :method => :clearlist

      match /accuse (.+)/i, :method => :accuse
      match /vote (yes|no)/i, :method => :vote
      match /status/i, :method => :status
      match /finalvote (.+)/i, :method => :finalvote
      match /unvote/i, :method => :unvote
      match /guess (.+)/i, :method => :guess_location
      match /guesslocation (.*)/i, :method => :guess_location

      match /help/i, :method => :help
      match /who/i, :method => :show_players_in_game
      match /aboutlocations/i, :method => :helplocations
      match /aboutchat/i, :method => :helpchat

      match /forcereset/i, :method => :forcereset
      match /reset/i, :method => :forcereset #all players can reset if they're in the game

      match /setlocations? (.*)/i, :method => :set_locations
      match /addlocations? (.*)/i, :method => :add_locations
      match /removelocations? (.*)/i, :method => :remove_locations

      match /lastguess/i, :method => :toggle_lastguess

      def help(m)
        User(m.user).send '--------Basic commands--------'
        User(m.user).send '!help to see this help screen'
        User(m.user).send '!aboutlocations to learn how to add, remove, set, and view locations'
        User(m.user).send '!aboutchat for optional play-by-chat functionality'
        User(m.user).send '!join to join a game'
        User(m.user).send '!leave to leave a game'
        User(m.user).send '!start to start a game'
        User(m.user).send '----------------'
        User(m.user).send '!accuse [target] to accuse a player of being a spy'
        User(m.user).send '!vote [yes|no] vote yes or no to an accusation'
        User(m.user).send '!finalvote [target] to vote for someone at game end'
        User(m.user).send '!unvote to secretly remove your vote'
        User(m.user).send '!status to see who needs to vote'
        User(m.user).send '!guess [location] to guess a location (Spy only)'
        User(m.user).send '----------------'
      end

      def helplocations(m)
        User(m.user).send '--------Location commands--------'
        User(m.user).send '!locations to privately view possible locations'
        User(m.user).send '!publiclocations to print locations to channel'
        User(m.user).send '!setlocations [location1, location2, ...] to set new locations'
        User(m.user).send '!addlocations [location1, location2, ...] to add new locations'
        User(m.user).send '!removelocations [location1, location2, ...] to remove locations'
        User(m.user).send '----------------'
      end

      def helpchat(m)
        User(m.user).send '--------Optional play-by-chat--------'
        User(m.user).send '!ask [target] [question...] to ask a question'
        User(m.user).send '!answer [question...] to answer a question'
        User(m.user).send '!answeredby [user] to indicate a user answered a question'
        User(m.user).send '!review to review all questions asked/answered this way'
        User(m.user).send '!remaining to list players who have yet to answer anything this way'
#        User(m.user).send '!clear [player] to add a player to your clear list'
#        User(m.user).send '!clearlist to review your clear list'
        User(m.user).send '----------------'
      end

      def join(m)
          if @active_game.started
            User(m.user).send 'Game already started'
          elsif @active_game.user_hash.include?(m.user.nick)
            Channel(@channel_name).send " #{m.user.nick} already joined. Game has #{@active_game.players_joined} player(s)."
          else
            @active_game.add_user(m.user)
            Channel(@channel_name).send " #{m.user.nick} joined. Game now has #{@active_game.players_joined} player(s)."
          end
      end

      def leave(m)
        if @active_game.started
          User(m.user).send 'Game already started'
        else
          @active_game.remove_user(m.user)
          Channel(@channel_name).send "#{m.user.nick} left. Game now has #{@active_game.players_joined} player(s)."
          end
      end

      def show_players_in_game(m)
        Channel(@channel_name).send "Players in game: #{@active_game.user_hash.keys.join(', ')}"
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
          last_spy=@active_game.last_game_spy_name
          if last_spy.nil?
            last_spy=@active_game.playing_user_names.first
            Channel(@channel_name).send "#{last_spy} was randomly chosen to start."
          else
            Channel(@channel_name).send "#{last_spy} was spy last game and starts this one."
          end
          self.send_locations

          @active_game.user_hash.values.each do |single_user|
            if single_user == @active_game.spy_user
              User(single_user).send 'You are the spy! Try to find the secret location.'
              User(single_user).send 'Use "!guess [location]" to guess the location.'
              User(single_user).send 'Use "!accuse [player]" to accuse a player.'
            else
              User(single_user).send "The location of interest is #{@active_game.actual_location}. Try to find the spy."
              User(single_user).send 'Use "!accuse [player]" to accuse a player.'
            end
          end

        end
      end

      def send_private_locations(m)
        #all users can see locations
        all_locations=@active_game.locations.join(', ')
        User(m.user).send "Locations being used: #{all_locations}"
      end

      def send_locations
        all_locations=@active_game.locations.join(', ')
        Channel(@channel_name).send "Locations being used: #{all_locations}"
      end

      def ask(m, raw_target, question)
        if @active_game.user_in_started_game?(m.user)
          target=@active_game.correct_caps_players(raw_target)
          target=raw_target unless target
          question=question.slice(0, 50) if question.length>50
          log_message="#{m.user.nick} asks #{target}: #{question}"
          Channel(@channel_name).send log_message
          @active_game.question_answer_log.push(log_message)
        end
      end

      def answer(m, response)
        if @active_game.user_in_started_game?(m.user)
          response=response.slice(0, 50) if response.length>50
          log_message="#{m.user.nick} responds: #{response}"
          Channel(@channel_name).send log_message
          @active_game.players_asked.push(m.user.nick) unless @active_game.players_asked.include?(m.user.nick)
          @active_game.question_answer_log.push(log_message)
        end
      end

      def answeredby(m, raw_target)
        if @active_game.user_in_started_game?(m.user)
          target=@active_game.correct_caps_players(raw_target)
          if target
            @active_game.players_asked.push(raw_target) unless @active_game.players_asked.include?(raw_target)
            #User(m.user).send "#{target} has answered."
          else
            target=raw_target
            User(m.user).send "#{target} doesn't seem to be in the player list."
          end
        end
      end

      def review(m)
        @active_game.question_answer_log.each do |message|
          User(m.user).send message
        end
      end

      def remaining(m)
        remaining_players=@active_game.playing_user_names.reject { |player_name| @active_game.players_asked.include?(player_name) }
        suggested_players=remaining_players.reject { |player_name| @active_game.clear_hash[m.user.nick].include?(player_name) }

        User(m.user).send "Players left to answer: #{remaining_players.join(', ')}"
        #User(m.user).send "Of those, these are uncleared: #{suggested_players.join(', ')}"
      end

      def clear(m, raw_target_name)
        target_name=accept_or_inform_in_game(raw_target_name, m.user)
        if target_name
          if @active_game.clear_hash[m.user.nick].include?(target_name)
            old_clear_list=@active_game.clear_hash[m.user.nick]
            new_clear_list=old_clear_list.delete(target_name)
            @active_game.clear_hash[m.user.nick]=new_clear_list
            User(m.user).send "You removed #{target_name} from your clear list"
          else
            old_clear_list=@active_game.clear_hash[m.user.nick]
            new_clear_list=old_clear_list.push(target_name)
            @active_game.clear_hash[m.user.nick]=new_clear_list
            User(m.user).send "You added #{target_name} to your clear list"
          end
          puts '==========='
          puts @active_game.clear_hash.keys.join(', ')
          puts '==========='
          @active_game.clear_hash.keys.each do |clear_name|
            puts '==='
            puts clear_name
            puts '='
            puts @active_game.clear_hash[clear_name].join(', ')
          end
          puts '==========='
        end
      end

      def clearlist(m)
        if @active_game.user_in_started_game?(m.user)
          User(m.user).send "You have cleared #{@active_game.clear_hash[m.user.nick].join(', ')}"
          puts '==========='
          puts @active_game.clear_hash.keys.join(', ')
          puts '==========='
          @active_game.clear_hash.keys.each do |clear_name|
            puts '==='
            puts clear_name
            puts '='
            puts @active_game.clear_hash[clear_name].join(', ')
          end
          puts '==========='
        end
      end

      def accuse(m, raw_target_name)
        target_name=accept_or_inform_in_game(raw_target_name, m.user)
        if target_name
          if @active_game.phase==:main
            @active_game.phase=:accusing
            @active_game.accuse_starter=m.user.nick
            @active_game.accused=target_name
            accuse_starter=@active_game.accuse_starter
            @active_game.votes={}
            puts '== Starting votes 0=='
            puts @active_game.votes
            @active_game.votes[accuse_starter]=target_name
            puts '== Starting votes 1=='
            puts @active_game.votes
            @active_game.votes[target_name]=''
            Channel(@channel_name).send "Player #{m.user.nick} accuses #{target_name} of being a spy!"
            Channel(@channel_name).send "Players should now vote if they agree. Use \"!vote yes\" or \"!vote no\""
            puts '== Starting votes 2=='
            puts @active_game.votes
          elsif @active_game.accused.nil?
            User(m.user).send 'You can not accuse someone now'
          else
            User(m.user).send "There's already an accusation for #{@active_game.accused}"
          end
        end
      end


      def vote(m, result) #method of processing vote input is diferent than finalvote
        if @active_game.user_in_started_game?(m.user)
          if @active_game.phase==:accusing
            if result.casecmp('yes').zero?
              @active_game.votes[m.user.nick]=@active_game.accused
            else
              @active_game.votes[m.user.nick] = ''
            end
            if @active_game.all_votes_in?
              self.check_votes
            else
              User(m.user).send "You voted #{result} for \"#{@active_game.accused}\""
            end
          else
            User(m.user).send 'Need to accuse someone first. Use !accuse [player] to accuse'
          end
        end
      end

      def status(m)
        if @active_game.user_in_started_game?(m.user)
          if @active_game.votes.empty?
            User(m.user).send "No votes have been cast yet"
          else
            remaining_voters=@active_game.playing_user_names.reject{|user_name|@active_game.votes.keys.include?(user_name)}
            User(m.user).send "Waiting on #{remaining_voters.join(', ')} to vote."
          end
        end
      end

      def finalvote(m, raw_target_name)
        target_name=accept_or_inform_in_game(raw_target_name, m.user)
        if target_name
          @active_game.votes[m.user.nick]=target_name
          if @active_game.all_votes_in?
            self.check_votes
          else
            User(m.user).send "Your vote is now set for \"#{@active_game.votes[m.user.nick]}\""
          end
        end
      end

      def unvote(m)
        if @active_game.player_during_main_phase?(m.user.nick)
          @active_game.votes.delete(m.user.nick)
          User(m.user).send 'Vote removed'
        end
      end

      def check_votes
        most_enough_voted_name=@active_game.most_voted_player_with_enough
        if most_enough_voted_name #evaluates false if not enough votes
          @active_game.accused=most_enough_voted_name
          self.display_accuse_results
        elsif @active_game.phase == :accusing
          accusers=@active_game.playing_user_names.select { |player_name| @active_game.votes[player_name]==@active_game.accused }
          Channel(@channel_name).send "Game continues -- player #{@active_game.accused} was only voted by #{accusers.join(', ')}"
          @active_game.phase=:main
          @active_game.accused=nil
          @active_game.accuse_starter=nil
          @active_game.votes={}
        elsif @active_game.phase == :main #finalvote
          spy_name=@active_game.spy_user.nick
          Channel(@channel_name).send "The agents are confused and don't agree. The spy (#{spy_name}) wins!"
          self.display_votes
          Channel(@channel_name).send "#{spy_name}, make a guess for the location with \"!guess [location]\""
          @active_game.phase=:guess
        else
          Channel(@channel_name).send 'The state is confused! Here\'s what the votes were.!'
          self.display_votes
        end
      end

      def display_votes
        single_vote_list=[]
        @active_game.votes.each do |voter, target|
          if target==''
            target='No accuse'
          end
          single_vote_list.push("#{voter}:#{target}")
        end
        Channel(@channel_name).send single_vote_list.join(', ')
      end

      def display_accuse_results
        @active_game.phase=:end
        accusers=@active_game.playing_user_names.select { |player_name| @active_game.votes[player_name]==@active_game.accused }
        end_game_message=''
        end_game_message="After #{@active_game.accuse_starter} made an accusation...\n" unless @active_game.accuse_starter.nil?
        Channel(@channel_name).send "#{end_game_message}Player #{@active_game.accused} has enough votes to be accused as spy!\nAccusers: #{accusers.join(', ')}"
        self.check_spy_against_accused
      end

      def check_spy_against_accused
        spy_name=@active_game.spy_user.nick
        if spy_name == @active_game.accused
          Channel(@channel_name).send 'The accusers are correct! Agents win!'
          self.reset_game
        else
          Channel(@channel_name).send "The accusers are wrong! The spy was #{spy_name}."
          Channel(@channel_name).send "#{spy_name}, make a guess for the location with \"!guess [location]\""
          @active_game.phase=:guess
        end
      end

      def guess_location(m, guessed_location)
        if m.user == @active_game.spy_user && (@active_game.phase==:main || @active_game.phase==:guess)
          if @active_game.locations.any? { |s| s.casecmp(guessed_location)==0 }
            @active_game.phase=:end #end game when location is guessed
            self.process_spy_guess(guessed_location)
            self.reset_game
          else
            User(m.user).send "Don't recognize #{guessed_location}. Please guess again or use !locations"
          end
        elsif @active_game.user_hash.keys.include?(m.user.nick)
          User(m.user).send 'Only the spy may guess the location.'
        end
      end

      def process_spy_guess(guessed_location)
        if @active_game.actual_location.downcase == guessed_location.downcase
          Channel(@channel_name).send "The spy #{@active_game.spy_user.nick} guessed the location #{guessed_location} correctly and wins!"
        else
          Channel(@channel_name).send "The spy #{@active_game.spy_user.nick} guessed the location #{guessed_location} but was wrong!"
          Channel(@channel_name).send "(The correct location was #{@active_game.actual_location}.)"
        end
      end

      def forcereset(m)
        #only users in the game can reset it
        self.reset_game if @active_game.user_in_started_game?(m.user)
      end

      def reset_game
        spy_name=@active_game.spy_user.nick
        agent_names=@active_game.playing_user_names.reject { |name| name==spy_name }
        Channel(@channel_name).send '=================================================='
        Channel(@channel_name).send "Spy: #{spy_name}, Agents: #{agent_names.join(', ')}"
        old_locations=@active_game.locations
        old_locations.delete(@active_game.actual_location)
        Channel(@channel_name).send "Location #{@active_game.actual_location} has been removed"
        Channel(@channel_name).send '=================================================='
        @active_game=Game.new
        @active_game.locations=old_locations
        @active_game.last_game_spy_name=spy_name
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
        Channel(@channel_name).send "Added #{new_locations.length} location(s)"
        self.send_locations
      end

      def remove_locations(m, location_string)
        new_locations=location_string.split(',')
        lower_game_locations=@active_game.locations.map { |a| a.downcase }

        new_locations.each do |single_location|
          single_location.strip!
          if lower_game_locations.include?(single_location.downcase)
            @active_game.locations.delete_if { |my_location| single_location.downcase==my_location.downcase }
          else
            User(m.user).send "Not in list: location #{single_location}"
            new_locations.delete(single_location)
          end
        end

        Channel(@channel_name).send "Removed #{new_locations.length} location(s)"
        self.send_locations
      end

      def toggle_lastguess(m)
        m.user
        on_after=@active_game.toggle_variant(:lastguess)
        if on_after
          Channel(@channel_name).send 'Last Guess turned on'
        else
          Channel(@channel_name).send 'Last Guess turned off'
        end
      end

      def accept_or_inform_in_game(target_player_name, inform_user)
        return nil unless @active_game.user_in_started_game?(inform_user)
        caps_player=@active_game.correct_caps_players(target_player_name)
        User(inform_user).send "Don't understand player \"#{target_player_name}\"" unless caps_player
        caps_player #return the name or nil if not found
      end

    end
  end
end