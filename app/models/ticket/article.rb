# Copyright (C) 2012-2014 Zammad Foundation, http://zammad-foundation.org/
class Ticket::Article < ApplicationModel
  load 'ticket/article/assets.rb'
  include Ticket::Article::Assets
  load 'ticket/article/history_log.rb'
  include Ticket::Article::HistoryLog
  load 'ticket/article/activity_stream_log.rb'
  include Ticket::Article::ActivityStreamLog

  belongs_to    :ticket
  belongs_to    :type,        class_name: 'Ticket::Article::Type'
  belongs_to    :sender,      class_name: 'Ticket::Article::Sender'
  belongs_to    :created_by,  class_name: 'User'
  belongs_to    :updated_by,  class_name: 'User'
  store         :preferences
  before_create :check_subject, :check_message_id_md5
  before_update :check_subject, :check_message_id_md5

  notify_clients_support

  activity_stream_support ignore_attributes: {
    type_id: true,
    sender_id: true,
    preferences: true,
  }

  history_support ignore_attributes: {
    type_id: true,
    sender_id: true,
    preferences: true,
  }

  # fillup md5 of message id to search easier on very long message ids
  def check_message_id_md5
    return if !message_id
    return if message_id_md5
    self.message_id_md5 = Digest::MD5.hexdigest(message_id.to_s)
  end

  # insert inline image urls
  def self.insert_urls(article, attachments)
    inline_attachments = {}
    article['body'].gsub!( /(<img\s(style.+?|)src=")cid:(.+?)(">)/i ) { |item|
      replace = item

      # look for attachment
      attachments.each {|file|
        next if !file.preferences['Content-ID'] || file.preferences['Content-ID'] != $3
        replace = "#{$1}/api/v1/ticket_attachment/#{article['ticket_id']}/#{article['id']}/#{file.id}#{$4}"
        inline_attachments[file.id] = true
        break
      }
      replace
    }
    new_attachments = []
    attachments.each {|file|
      next if inline_attachments[file.id]
      new_attachments.push file
    }
    article['attachments'] = new_attachments
    article
  end

  private

  # strip not wanted chars
  def check_subject
    return if !subject
    subject.gsub!(/\s|\t|\r/, ' ')
  end

  class Flag < ApplicationModel
  end

  class Sender < ApplicationModel
    validates :name, presence: true
    latest_change_support
  end

  class Type < ApplicationModel
    validates :name, presence: true
    latest_change_support
  end
end
