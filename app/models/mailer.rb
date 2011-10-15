# Redmine - project management software
# Copyright (C) 2006-2011  Jean-Philippe Lang
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

require 'ar_condition'

class BlackholeMailMessage < Mail::Message
  def self.deliver
    false
  end
end

class AbortDeliveryError < StandardError
end

class Mailer < ActionMailer::Base
  layout 'mailer'
  helper :application
  helper :issues
  helper :custom_fields

  # include ActionController::UrlWriter
  include ActionDispatch::Routing::UrlFor
  include Redmine::I18n

  self.prepend_view_path "app/views/mailer"
  
  def abort_delivery
    raise AbortDeliveryError
  end

  def process(*args)
    begin
      super *args
    rescue AbortDeliveryError
      self.message = BlackholeMailMessage
    end
  end

  def self.default_url_options
    h = Setting.host_name
    h = h.to_s.gsub(%r{\/.*$}, '') unless Redmine::Utils.relative_url_root.blank?
    { :host => h, :protocol => Setting.protocol }
  end
  
  # Builds a tmail object used to email recipients of the added issue.
  #
  # Example:
  #   issue_add(issue) => tmail object
  #   Mailer.deliver_issue_add(issue) => sends an email to issue recipients
  def issue_add(issue)
    redmine_headers 'Project' => issue.project.identifier,
                    'Issue-Id' => issue.id,
                    'Issue-Author' => issue.author.login
    redmine_headers 'Issue-Assignee' => issue.assigned_to.login if issue.assigned_to
    
    @issue = issue
    @issue_url = url_for(:controller => 'issues', :action => 'show', :id => issue)
    mail "issue_add", :message_id => issue,
      :to => issue.recipients,
      :cc => (issue.watcher_recipients - issue.recipients),
      :subject => "[#{issue.project.name} - #{issue.tracker.name} ##{issue.id}] (#{issue.status.name}) #{issue.subject}"
  end

  # Builds a tmail object used to email recipients of the edited issue.
  #
  # Example:
  #   issue_edit(journal) => tmail object
  #   Mailer.deliver_issue_edit(journal) => sends an email to issue recipients
  def issue_edit(journal)
    issue = journal.journalized.reload
    redmine_headers 'Project' => issue.project.identifier,
                    'Issue-Id' => issue.id,
                    'Issue-Author' => issue.author.login
    redmine_headers 'Issue-Assignee' => issue.assigned_to.login if issue.assigned_to

    @author = journal.user
    s = "[#{issue.project.name} - #{issue.tracker.name} ##{issue.id}] "
    s << "(#{issue.status.name}) " if journal.new_value_for('status_id')
    s << issue.subject
    @issue = issue
    @journal = journal
    @issue_url = url_for(:controller => 'issues', :action => 'show', :id => issue)
    mail "issue_edit", :message_id => journal,
      :references => issue,
      :to => issue.recipients,
      :cc => (issue.watcher_recipients - issue.recipients), # Watchers in cc
      :subject => s
  end

  def reminder(user, issues, days)
    set_language_if_valid user.language
    @issues = issues
    @days = days
    @issues_url = url_for(:controller => 'issues', :action => 'index', :set_filter => 1, :assigned_to_id => user.id, :sort => 'due_date:asc')
    mail "reminder", :to => user.mail,
      :subject => l(:mail_subject_reminder, :count => issues.size, :days => days)
  end

  # Builds a tmail object used to email users belonging to the added document's project.
  #
  # Example:
  #   document_added(document) => tmail object
  #   Mailer.deliver_document_added(document) => sends an email to the document's project recipients
  def document_added(document)
    redmine_headers 'Project' => document.project.identifier
    @document = document
    @document_url = url_for(:controller => 'documents', :action => 'show', :id => document)
    mail "document_added", :to => document.recipients,
      :subject => "[#{document.project.name}] #{l(:label_document_new)}: #{document.title}"
  end

  # Builds a tmail object used to email recipients of a project when an attachements are added.
  #
  # Example:
  #   attachments_added(attachments) => tmail object
  #   Mailer.deliver_attachments_added(attachments) => sends an email to the project's recipients
  def attachments_added(attachments)
    container = attachments.first.container
    added_to = ''
    added_to_url = ''
    recipients = []
    case container.class.name
    when 'Project'
      added_to_url = url_for(:controller => 'files', :action => 'index', :project_id => container)
      added_to = "#{l(:label_project)}: #{container}"
      recipients = container.project.notified_users.select {|user| user.allowed_to?(:view_files, container.project)}.collect  {|u| u.mail}
    when 'Version'
      added_to_url = url_for(:controller => 'files', :action => 'index', :project_id => container.project)
      added_to = "#{l(:label_version)}: #{container.name}"
      recipients = container.project.notified_users.select {|user| user.allowed_to?(:view_files, container.project)}.collect  {|u| u.mail}
    when 'Document'
      added_to_url = url_for(:controller => 'documents', :action => 'show', :id => container.id)
      added_to = "#{l(:label_document)}: #{container.title}"
      recipients = container.recipients
    end
    redmine_headers 'Project' => container.project.identifier
    
    @attachments = attachments
    @added_to = added_to
    @added_to_url = added_to_url
    mail "attachments_added", :subject => "[#{container.project.name}] #{l(:label_attachment_new)}", :to => recipients
  end
  
  # Builds a tmail object used to email recipients of a news' project when a news item is added.
  #
  # Example:
  #   news_added(news) => tmail object
  #   Mailer.deliver_news_added(news) => sends an email to the news' project recipients
  def news_added(news)
    redmine_headers 'Project' => news.project.identifier

    @news = news
    @news_url = url_for(:controller => 'news', :action => 'show', :id => news)
    mail "news_added", :message_id => news,
      :to => news.recipients,
      :subject => "[#{news.project.name}] #{l(:label_news)}: #{news.title}"
  end
  
  # Builds a tmail object used to email recipients of a news' project when a news comment is added.
  #
  # Example:
  #   news_comment_added(comment) => tmail object
  #   Mailer.news_comment_added(comment) => sends an email to the news' project recipients
  def news_comment_added(comment)
    news = comment.commented
    redmine_headers 'Project' => news.project.identifier
    @news = news
    @comment = comment
    @news_url = url_for(:controller => 'news', :action => 'show', :id => news)
    mail "news_comment_added", :message_id => comment,
      :to => news.recipients,
      :cc => news.watcher_recipients,
      :subject => "Re: [#{news.project.name}] #{l(:label_news)}: #{news.title}"
  end

  # Builds a tmail object used to email the recipients of the specified message that was posted. 
  #
  # Example:
  #   message_posted(message) => tmail object
  #   Mailer.deliver_message_posted(message) => sends an email to the recipients
  def message_posted(message)
    redmine_headers 'Project' => message.project.identifier,
                    'Topic-Id' => (message.parent_id || message.id)
    @message = message
    @message_url = url_for(message.event_url)

    mail "message_posted", :message_id => message,
      :references => message.parent,
      :to => message.recipients,
      :cc => ((message.root.watcher_recipients + message.board.watcher_recipients).uniq - message.recipients),
      :subject => "[#{message.board.project.name} - #{message.board.name} - msg#{message.root.id}] #{message.subject}"
  end
  
  # Builds a tmail object used to email the recipients of a project of the specified wiki content was added. 
  #
  # Example:
  #   wiki_content_added(wiki_content) => tmail object
  #   Mailer.deliver_wiki_content_added(wiki_content) => sends an email to the project's recipients
  def wiki_content_added(wiki_content)
    redmine_headers 'Project' => wiki_content.project.identifier,
                    'Wiki-Page-Id' => wiki_content.page.id
    @wiki_content = wiki_content
    @wiki_content_url = url_for(:controller => 'wiki', :action => 'show', :project_id => wiki_content.project, :id => wiki_content.page.title)
    mail "wiki_content_added", :message_id => wiki_content,
      :to => wiki_content.recipients,
      :cc => (wiki_content.page.wiki.watcher_recipients - wiki_content.recipients),
      :subject => "[#{wiki_content.project.name}] #{l(:mail_subject_wiki_content_added, :id => wiki_content.page.pretty_title)}"
  end
  
  # Builds a tmail object used to email the recipients of a project of the specified wiki content was updated. 
  #
  # Example:
  #   wiki_content_updated(wiki_content) => tmail object
  #   Mailer.deliver_wiki_content_updated(wiki_content) => sends an email to the project's recipients
  def wiki_content_updated(wiki_content)
    redmine_headers 'Project' => wiki_content.project.identifier,
                    'Wiki-Page-Id' => wiki_content.page.id
    @wiki_content = wiki_content
    @wiki_content_url = url_for(:controller => 'wiki', :action => 'show', :project_id => wiki_content.project, :id => wiki_content.page.title)
    @wiki_diff_url = url_for(:controller => 'wiki', :action => 'diff', :project_id => wiki_content.project, :id => wiki_content.page.title, :version => wiki_content.version)
    mail "wiki_content_updated", :message_id => wiki_content,
      :to => wiki_content.recipients,
      :cc => (wiki_content.page.wiki.watcher_recipients + wiki_content.page.watcher_recipients - wiki_content.recipients),
      :subject => "[#{wiki_content.project.name}] #{l(:mail_subject_wiki_content_updated, :id => wiki_content.page.pretty_title)}",
  end

  # Builds a tmail object used to email the specified user their account information.
  #
  # Example:
  #   account_information(user, password) => tmail object
  #   Mailer.deliver_account_information(user, password) => sends account information to the user
  def account_information(user, password)
    set_language_if_valid user.language

    @user = user
    @password = password
    @login_url = url_for(:controller => 'account', :action => 'login')
    mail "account_information", :to => user.mail,
      :subject => l(:mail_subject_register, Setting.app_title),
  end

  # Builds a tmail object used to email all active administrators of an account activation request.
  #
  # Example:
  #   account_activation_request(user) => tmail object
  #   Mailer.deliver_account_activation_request(user)=> sends an email to all active administrators
  def account_activation_request(user)
    # Send the email to all active administrators
    @user = user
    @url = url_for(:controller => 'users', :action => 'index', :status => User::STATUS_REGISTERED, :sort_key => 'created_on', :sort_order => 'desc')

    mail "account_activation_request", :to => User.active.find(:all, :conditions => {:admin => true}).collect { |u| u.mail }.compact,
      :subject => l(:mail_subject_account_activation_request, Setting.app_title)
  end

  # Builds a tmail object used to email the specified user that their account was activated by an administrator.
  #
  # Example:
  #   account_activated(user) => tmail object
  #   Mailer.deliver_account_activated(user) => sends an email to the registered user
  def account_activated(user)
    set_language_if_valid user.language
    @user = user
    @login_url = url_for(:controller => 'account', :action => 'login')
    mail "account_activated", :to => user.mail,
      :subject => l(:mail_subject_register, Setting.app_title)
  end

  def lost_password(token)
    set_language_if_valid(token.user.language)

    @token = token
    @url = url_for(:controller => 'account', :action => 'lost_password', :token => token.value)
    mail "lost_password", :to => token.user.mail,
      :subject => l(:mail_subject_lost_password, Setting.app_title),
  end

  def register(token)
    set_language_if_valid(token.user.language)

    @token = token
    @url = url_for(:controller => 'account', :action => 'activate', :token => token.value)
    mail "register", :to => token.user.mail,
      :subject => l(:mail_subject_register, Setting.app_title)
  end

  def test(user)
    set_language_if_valid(user.language)

    @url = url_for(:controller => 'welcome')
    mail "test", :to => user.mail,
      :subject => 'Redmine test'
  end

  # Sends reminders to issue assignees
  # Available options:
  # * :days     => how many days in the future to remind about (defaults to 7)
  # * :tracker  => id of tracker for filtering issues (defaults to all trackers)
  # * :project  => id or identifier of project to process (defaults to all projects)
  # * :users    => array of user ids who should be reminded
  def self.reminders(options={})
    days = options[:days] || 7
    project = options[:project] ? Project.find(options[:project]) : nil
    tracker = options[:tracker] ? Tracker.find(options[:tracker]) : nil
    user_ids = options[:users]

    s = ARCondition.new ["#{IssueStatus.table_name}.is_closed = ? AND #{Issue.table_name}.due_date <= ?", false, days.day.from_now.to_date]
    s << "#{Issue.table_name}.assigned_to_id IS NOT NULL"
    s << ["#{Issue.table_name}.assigned_to_id IN (?)", user_ids] if user_ids.present?
    s << "#{Project.table_name}.status = #{Project::STATUS_ACTIVE}"
    s << "#{Issue.table_name}.project_id = #{project.id}" if project
    s << "#{Issue.table_name}.tracker_id = #{tracker.id}" if tracker

    issues_by_assignee = Issue.find(:all, :include => [:status, :assigned_to, :project, :tracker],
                                          :conditions => s.conditions
                                    ).group_by(&:assigned_to)
    issues_by_assignee.each do |assignee, issues|
      reminder(assignee, issues, days).deliver if assignee && assignee.active?
    end
  end
  
  # Activates/desactivates email deliveries during +block+
  def self.with_deliveries(enabled = true, &block)
    was_enabled = ActionMailer::Base.perform_deliveries
    ActionMailer::Base.perform_deliveries = !!enabled
    yield
  ensure
    ActionMailer::Base.perform_deliveries = was_enabled
  end

  private
  def initialize_defaults(method_name)
    super
    @initial_language = current_language
    set_language_if_valid Setting.default_language
    
    # Common headers
    headers 'X-Mailer' => 'Redmine',
            'X-Redmine-Host' => Setting.host_name,
            'X-Redmine-Site' => Setting.app_title,
            'Precedence' => 'bulk',
            'Auto-Submitted' => 'auto-generated'
  end

  # Appends a Redmine header field (name is prepended with 'X-Redmine-')
  def redmine_headers(h)
    h.each { |k,v| headers["X-Redmine-#{k}"] = v.to_s }
  end

  alias :mail_without_default_settings :mail
  def mail(method_name, attributes)
    attributes[:from] = Setting.mail_from
    
    @author ||= User.current
    if @author.pref[:no_self_notified]
      attributes[:to].delete(@author.mail) if attributes[:to]
      attributes[:cc].delete(@author.mail) if attributes[:cc]
    end

    if Setting.bcc_recipients?
      attributes[:bcc] = [attributes[:to], attributes[:cc]].flatten.compact.uniq
      attributes[:cc] = []
      attributes[:to] = []
    end
    
    set_language_if_valid @initial_language
    abort_delivery if (attributes[:to].nil? || attributes[:to].empty?) &&
                      (attributes[:cc].nil? || attributes[:cc] .empty?) &&
                      (attributes[:bcc].nil? || attributes[:bcc].empty?)
              
    # Set Message-Id and References
    if attributes[:message_id]
      attributes[:message_id] = self.class.message_id_for(attributes[:message_id])
    end
    if attributes[:references]
      attributes[:references] = self.class.message_id_for(attributes[:references])
    end
    
    # Log errors when raise_delivery_errors is set to false, Rails does not
    raise_errors = self.class.raise_delivery_errors
    self.class.raise_delivery_errors = true
    begin
      mail_without_default_settings(attributes) do |format|
        format.text { render :file  => "#{method_name}.text.erb", :layout => 'mailer.html.erb' }
        format.html { render :file => "#{method_name}.html.erb", :layout => 'mailer.html.erb' } if !Setting.plain_text_mail?
      end
    rescue Exception => e
      if raise_errors
        raise e
      elsif mylogger
        mylogger.error "The following error occured while sending email notification: \"#{e.message}\". Check your configuration in config/configuration.yml."
      end
    ensure
      self.class.raise_delivery_errors = raise_errors
    end
  end
  
  # Returns a predictable Message-Id for the given object
  def self.message_id_for(object)
    # id + timestamp should reduce the odds of a collision
    # as far as we don't send multiple emails for the same object
    timestamp = object.send(object.respond_to?(:created_on) ? :created_on : :updated_on) 
    hash = "redmine.#{object.class.name.demodulize.underscore}-#{object.id}.#{timestamp.strftime("%Y%m%d%H%M%S")}"
    host = Setting.mail_from.to_s.gsub(%r{^.*@}, '')
    host = "#{::Socket.gethostname}.redmine" if host.empty?
    "<#{hash}@#{host}>"
  end
  
  private
  
  def mylogger
    Rails.logger
  end
end

# Patch TMail so that message_id is not overwritten
module TMail
  class Mail
    def add_message_id( fqdn = nil )
      self.message_id ||= ::TMail::new_message_id(fqdn)
    end
  end
end
