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

require File.expand_path('../../test_helper', __FILE__)

class MailerTest < ActiveSupport::TestCase
  include Redmine::I18n
  include ActionDispatch::Assertions::SelectorAssertions
  
  fixtures :projects, :enabled_modules, :issues, :users, :members,
           :member_roles, :roles, :documents, :attachments, :news,
           :tokens, :journals, :journal_details, :changesets, :trackers,
           :issue_statuses, :enumerations, :messages, :boards, :repositories,
           :wikis, :wiki_pages, :wiki_contents, :wiki_content_versions,
           :versions,
           :comments

  def setup
    ActionMailer::Base.deliveries.clear
    Setting.host_name = 'mydomain.foo'
    Setting.protocol = 'http'
    Setting.plain_text_mail = '0'
  end

  def test_generated_links_in_emails
    Setting.host_name = 'mydomain.foo'
    Setting.protocol = 'https'

    journal = Journal.find(2)
    assert Mailer.issue_edit(journal).deliver

    mail = ActionMailer::Base.deliveries.last
    assert_kind_of Mail::Message, mail

    assert_select_email do
      # link to the main ticket
      assert_select "a[href=?]",
                    "https://mydomain.foo/issues/1",
                    :text => "Bug #1: Can't print recipes"
      # link to a referenced ticket
      assert_select "a[href=?][title=?]",
                    "https://mydomain.foo/issues/2",
                    "Add ingredients categories (Assigned)",
                    :text => "#2"
      # link to a changeset
      assert_select "a[href=?][title=?]",
                    "https://mydomain.foo/projects/ecookbook/repository/revisions/2",
                    "This commit fixes #1, #2 and references #1 &amp; #3",
                    :text => "r2"
    end
  end

  def test_generated_links_with_prefix
    relative_url_root = Redmine::Utils.relative_url_root
    Setting.host_name = 'mydomain.foo/rdm'
    Setting.protocol = 'http'
    Redmine::Utils.relative_url_root = '/rdm'

    journal = Journal.find(2)
    assert Mailer.issue_edit(journal).deliver

    mail = ActionMailer::Base.deliveries.last
    assert_kind_of Mail::Message, mail

    assert_select_email do
      # link to the main ticket
      assert_select "a[href=?]",
                    "http://mydomain.foo/rdm/issues/1",
                    :text => "Bug #1: Can't print recipes"
      # link to a referenced ticket
      assert_select "a[href=?][title=?]",
                    "http://mydomain.foo/rdm/issues/2",
                    "Add ingredients categories (Assigned)",
                    :text => "#2"
      # link to a changeset
      assert_select "a[href=?][title=?]",
                    "http://mydomain.foo/rdm/projects/ecookbook/repository/revisions/2",
                    "This commit fixes #1, #2 and references #1 &amp; #3",
                    :text => "r2"
    end
  ensure
    # restore it
    Redmine::Utils.relative_url_root = relative_url_root
  end

  def test_generated_links_with_prefix_and_no_relative_url_root
    relative_url_root = Redmine::Utils.relative_url_root
    Setting.host_name = 'mydomain.foo/rdm'
    Setting.protocol = 'http'
    Redmine::Utils.relative_url_root = nil

    journal = Journal.find(2)
    assert Mailer.issue_edit(journal).deliver

    mail = ActionMailer::Base.deliveries.last
    assert_kind_of Mail::Message, mail

    assert_select_email do
      # link to the main ticket
      assert_select "a[href=?]",
                    "http://mydomain.foo/rdm/issues/1",
                    :text => "Bug #1: Can't print recipes"
      # link to a referenced ticket
      assert_select "a[href=?][title=?]",
                    "http://mydomain.foo/rdm/issues/2",
                    "Add ingredients categories (Assigned)",
                    :text => "#2"
      # link to a changeset
      assert_select "a[href=?][title=?]",
                    "http://mydomain.foo/rdm/projects/ecookbook/repository/revisions/2",
                    "This commit fixes #1, #2 and references #1 &amp; #3",
                    :text => "r2"
    end
  ensure
    # restore it
    Redmine::Utils.relative_url_root = relative_url_root
  end

  def test_email_headers
    issue = Issue.find(1)
    Mailer.issue_add(issue).deliver
    mail = ActionMailer::Base.deliveries.last
    assert_not_nil mail
    assert_equal 'bulk', mail.headers['Precedence']
    assert_equal 'auto-generated', mail.headers['Auto-Submitted']
  end

  def test_plain_text_mail
    Setting.plain_text_mail = 1
    journal = Journal.find(2)
    Mailer.issue_edit(journal).deliver
    mail = ActionMailer::Base.deliveries.last
    assert_equal "text/plain; charset=UTF-8", mail.content_type
    assert_equal 0, mail.parts.size
    assert !mail.encoded.include?('href')
  end

  def test_html_mail
    Setting.plain_text_mail = 0
    journal = Journal.find(2)
    Mailer.issue_edit(journal).deliver
    mail = ActionMailer::Base.deliveries.last
    assert_equal 2, mail.parts.size
    assert mail.encoded.include?('href')
  end

  def test_mail_from_with_phrase
    with_settings :mail_from => 'Redmine app <redmine@example.net>' do
      Mailer.test(User.find(1)).deliver
    end
    mail = ActionMailer::Base.deliveries.last
    assert_not_nil mail
    assert_equal 'redmine@example.net', mail.from_addrs.first
  end

  def test_should_not_send_email_without_recipient
    news = News.find(:first)
    user = news.author
    # Remove members except news author
    news.project.memberships.each {|m| m.destroy unless m.user == user}

    user.pref[:no_self_notified] = false
    user.pref.save
    User.current = user
    Mailer.news_added(news.reload).deliver
    assert_equal 1, last_email.bcc.size

    # nobody to notify
    user.pref[:no_self_notified] = true
    user.pref.save
    User.current = user
    ActionMailer::Base.deliveries.clear
    Mailer.news_added(news.reload).deliver
    assert ActionMailer::Base.deliveries.empty?
  end

  def test_issue_add_message_id
    issue = Issue.find(1)
    Mailer.issue_add(issue).deliver
    mail = ActionMailer::Base.deliveries.last
    assert_not_nil mail
    assert_equal Mailer.message_id_for(issue), "<" + mail.message_id + ">"
    assert_nil mail.references
  end

  def test_issue_edit_message_id
    journal = Journal.find(1)
    Mailer.issue_edit(journal).deliver
    mail = ActionMailer::Base.deliveries.last
    assert_not_nil mail
    assert_equal Mailer.message_id_for(journal), "<" + mail.message_id + ">"
    assert_equal Mailer.message_id_for(journal.issue), "<" + mail.references + ">"
  end

  def test_message_posted_message_id
    message = Message.find(1)
    Mailer.message_posted(message).deliver
    mail = ActionMailer::Base.deliveries.last
    assert_not_nil mail
    assert_equal Mailer.message_id_for(message), "<" + mail.message_id + ">"
    assert_nil mail.references
    assert_select_email do
      # link to the message
      assert_select "a[href=?]",
                    "http://mydomain.foo/boards/#{message.board.id}/topics/#{message.id}",
                    :text => message.subject
    end
  end

  def test_reply_posted_message_id
    message = Message.find(3)
    Mailer.message_posted(message).deliver
    mail = ActionMailer::Base.deliveries.last
    assert_not_nil mail
    assert_equal Mailer.message_id_for(message), "<" + mail.message_id + ">"
    assert_equal Mailer.message_id_for(message.parent), "<" + mail.references + ">"
    assert_select_email do
      # link to the reply
      assert_select "a[href=?]",
                    "http://mydomain.foo/boards/#{message.board.id}/topics/#{message.root.id}?r=#{message.id}#message-#{message.id}",
                    :text => message.subject
    end
  end

  context("#issue_add") do
    setup do
      ActionMailer::Base.deliveries.clear
      Setting.bcc_recipients = '1'
      @issue = Issue.find(1)
    end

    should "notify project members" do
      assert Mailer.issue_add(@issue).deliver
      assert last_email.bcc.include?('dlopper@somenet.foo')
    end

    should "not notify project members that are not allow to view the issue" do
      Role.find(2).remove_permission!(:view_issues)
      assert Mailer.issue_add(@issue).deliver
      assert !last_email.bcc.include?('dlopper@somenet.foo')
    end

    should "notify issue watchers" do
      user = User.find(9)
      # minimal email notification options
      user.pref[:no_self_notified] = '1'
      user.pref.save
      user.mail_notification = false
      user.save

      Watcher.create!(:watchable => @issue, :user => user)
      assert Mailer.issue_add(@issue).deliver
      assert last_email.bcc.include?(user.mail)
    end

    should "not notify watchers not allowed to view the issue" do
      user = User.find(9)
      Watcher.create!(:watchable => @issue, :user => user)
      Role.non_member.remove_permission!(:view_issues)
      assert Mailer.issue_add(@issue).deliver
      assert !last_email.bcc.include?(user.mail)
    end
  end

  # test mailer methods for each language
  def test_issue_add
    issue = Issue.find(1)
    valid_languages.each do |lang|
      Setting.default_language = lang.to_s
      assert Mailer.issue_add(issue).deliver
    end
  end

  def test_issue_edit
    journal = Journal.find(1)
    valid_languages.each do |lang|
      Setting.default_language = lang.to_s
      assert Mailer.issue_edit(journal).deliver
    end
  end

  def test_document_added
    document = Document.find(1)
    valid_languages.each do |lang|
      Setting.default_language = lang.to_s
      assert Mailer.document_added(document).deliver
    end
  end

  def test_attachments_added
    attachements = [ Attachment.find_by_container_type('Document') ]
    valid_languages.each do |lang|
      Setting.default_language = lang.to_s
      assert Mailer.attachments_added(attachements).deliver
    end
  end

  def test_version_file_added
    attachements = [ Attachment.find_by_container_type('Version') ]
    assert Mailer.attachments_added(attachements).deliver
    assert_not_nil last_email.bcc
    assert last_email.bcc.any?
    assert_select_email do
      assert_select "a[href=?]", "http://mydomain.foo/projects/ecookbook/files"
    end
  end

  def test_project_file_added
    attachements = [ Attachment.find_by_container_type('Project') ]
    assert Mailer.attachments_added(attachements).deliver
    assert_not_nil last_email.bcc
    assert last_email.bcc.any?
    assert_select_email do
      assert_select "a[href=?]", "http://mydomain.foo/projects/ecookbook/files"
    end
  end

  def test_news_added
    news = News.find(:first)
    valid_languages.each do |lang|
      Setting.default_language = lang.to_s
      assert Mailer.news_added(news).deliver
    end
  end

  def test_news_comment_added
    comment = Comment.find(2)
    valid_languages.each do |lang|
      Setting.default_language = lang.to_s
      assert Mailer.news_comment_added(comment).deliver
    end
  end

  def test_message_posted
    message = Message.find(:first)
    recipients = ([message.root] + message.root.children).collect {|m| m.author.mail if m.author}
    recipients = recipients.compact.uniq
    valid_languages.each do |lang|
      Setting.default_language = lang.to_s
      assert Mailer.message_posted(message).deliver
    end
  end

  def test_wiki_content_added
    content = WikiContent.find(:first)
    valid_languages.each do |lang|
      Setting.default_language = lang.to_s
      assert_difference 'ActionMailer::Base.deliveries.size' do
        assert Mailer.wiki_content_added(content).deliver
      end
    end
  end

  def test_wiki_content_updated
    content = WikiContent.find(:first)
    valid_languages.each do |lang|
      Setting.default_language = lang.to_s
      assert_difference 'ActionMailer::Base.deliveries.size' do
        assert Mailer.wiki_content_updated(content).deliver
      end
    end
  end

  def test_account_information
    user = User.find(2)
    valid_languages.each do |lang|
      user.update_attribute :language, lang.to_s
      user.reload
      assert Mailer.account_information(user, 'pAsswORd').deliver
    end
  end

  def test_lost_password
    token = Token.find(2)
    valid_languages.each do |lang|
      token.user.update_attribute :language, lang.to_s
      token.reload
      assert Mailer.lost_password(token).deliver
    end
  end

  def test_register
    token = Token.find(1)
    Setting.host_name = 'redmine.foo'
    Setting.protocol = 'https'

    valid_languages.each do |lang|
      token.user.update_attribute :language, lang.to_s
      token.reload
      ActionMailer::Base.deliveries.clear
      assert Mailer.register(token).deliver
      mail = ActionMailer::Base.deliveries.last
      assert mail.body.encoded.include?("https://redmine.foo/account/activate?token=#{token.value}")
    end
  end

  def test_test
    user = User.find(1)
    valid_languages.each do |lang|
      user.update_attribute :language, lang.to_s
      assert Mailer.test(user).deliver
    end
  end

  def test_reminders
    Mailer.reminders(:days => 42)
    assert_equal 1, ActionMailer::Base.deliveries.size
    mail = ActionMailer::Base.deliveries.last
    assert mail.bcc.include?('dlopper@somenet.foo')
    assert mail.body.encoded.include?('Bug #3: Error 281 when updating a recipe')
    assert_equal '1 issue(s) due in the next 42 days', mail.subject
  end

  def test_reminders_for_users
    Mailer.reminders(:days => 42, :users => ['5'])
    assert_equal 0, ActionMailer::Base.deliveries.size # No mail for dlopper
    Mailer.reminders(:days => 42, :users => ['3'])
    assert_equal 1, ActionMailer::Base.deliveries.size # No mail for dlopper
    mail = ActionMailer::Base.deliveries.last
    assert mail.bcc.include?('dlopper@somenet.foo')
    assert mail.body.encoded.include?('Bug #3: Error 281 when updating a recipe')
  end

  def last_email
    mail = ActionMailer::Base.deliveries.last
    assert_not_nil mail
    mail
  end

  def test_mailer_should_not_change_locale
    Setting.default_language = 'en'
    # Set current language to italian
    set_language_if_valid 'it'
    # Send an email to a french user
    user = User.find(1)
    user.language = 'fr'
    Mailer.account_activated(user).deliver
    mail = ActionMailer::Base.deliveries.last
    assert mail.body.encoded.include?('Votre compte')

    assert_equal :it, current_language
  end

  def test_with_deliveries_off
    Mailer.with_deliveries false do
      Mailer.test(User.find(1)).deliver
    end
    assert ActionMailer::Base.deliveries.empty?
    # should restore perform_deliveries
    assert ActionMailer::Base.perform_deliveries
  end

  context "layout" do
    should "include the emails_header" do
      with_settings(:emails_header => "*Header content*") do
        assert Mailer.test(User.find(1)).deliver

        assert_select_email do
          assert_select ".header" do
            assert_select "strong", :text => "Header content"
          end
        end
      end
    end
  end
end
