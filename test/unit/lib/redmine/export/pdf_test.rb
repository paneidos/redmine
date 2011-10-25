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

require File.expand_path('../../../../../test_helper', __FILE__)
require 'iconv'

class PdfTest < ActiveSupport::TestCase
  include Redmine::I18n

  def test_fix_text_encoding_nil
    set_language_if_valid 'ja'
    assert_equal 'CP932', l(:general_pdf_encoding)
    if RUBY_VERSION < '1.9' 
      if RUBY_PLATFORM == 'java'
        ic = Iconv.new("SJIS", 'UTF-8')
      else
        ic = Iconv.new(l(:general_pdf_encoding), 'UTF-8')
      end
    end
    assert_equal '', Redmine::Export::PDF::RDMPdfEncoding::rdm_pdf_iconv(ic, nil)
  end

  def test_fix_text_decoding_nil
    set_language_if_valid 'ja'
    assert_equal 'CP932', l(:general_pdf_encoding)
    if RUBY_VERSION < '1.9' 
      if RUBY_PLATFORM == 'java'
        ic = Iconv.new("UTF-8", 'SJIS')
      else
        ic = Iconv.new('UTF-8', l(:general_pdf_encoding))
      end
    end
    assert_equal '', Redmine::Export::PDF::RDMPdfEncoding::rdm_pdf_iconv(ic, nil, true)
  end

  def test_rdm_pdf_iconv_cannot_convert_ja_to_cp932
    set_language_if_valid 'ja'
    assert_equal 'CP932', l(:general_pdf_encoding)
    if RUBY_VERSION < '1.9'
      if RUBY_PLATFORM == 'java'
        ic = Iconv.new("SJIS", 'UTF-8')
      else
        ic = Iconv.new(l(:general_pdf_encoding), 'UTF-8')
      end
    end
    # \xe7\x8b\x80 : invalid UTF-8 character
    # \xe6\x85\x8b :   valid UTF-8 character => \x91\xd4 : valid CP932 character
    utf8_txt_1  = "\xe7\x8b\x80\xe6\x85\x8b"
    utf8_txt_2  = "\xe7\x8b\x80\xe6\x85\x8b\xe7\x8b\x80"
    utf8_txt_3  = "\xe7\x8b\x80\xe7\x8b\x80\xe6\x85\x8b\xe7\x8b\x80"
    if utf8_txt_1.respond_to?(:force_encoding)
      txt_1 = Redmine::Export::PDF::RDMPdfEncoding::rdm_pdf_iconv(ic, utf8_txt_1)
      txt_2 = Redmine::Export::PDF::RDMPdfEncoding::rdm_pdf_iconv(ic, utf8_txt_2)
      txt_3 = Redmine::Export::PDF::RDMPdfEncoding::rdm_pdf_iconv(ic, utf8_txt_3)
      assert_equal "?\x91\xd4", txt_1
      assert_equal "?\x91\xd4?", txt_2
      assert_equal "??\x91\xd4?", txt_3
      assert_equal "UTF-8", utf8_txt_1.encoding.to_s
      assert_equal "UTF-8", utf8_txt_2.encoding.to_s
      assert_equal "UTF-8", utf8_txt_3.encoding.to_s
      assert_equal "ASCII-8BIT", txt_1.encoding.to_s
      assert_equal "ASCII-8BIT", txt_2.encoding.to_s
      assert_equal "ASCII-8BIT", txt_3.encoding.to_s
    elsif RUBY_PLATFORM == 'java'
      assert_equal "??",
                   Redmine::Export::PDF::RDMPdfEncoding::rdm_pdf_iconv(ic, utf8_txt_1)
      assert_equal "???",
                   Redmine::Export::PDF::RDMPdfEncoding::rdm_pdf_iconv(ic, utf8_txt_2)
      assert_equal "????",
                   Redmine::Export::PDF::RDMPdfEncoding::rdm_pdf_iconv(ic, utf8_txt_3)
    else
      assert_equal "???\x91\xd4",
                   Redmine::Export::PDF::RDMPdfEncoding::rdm_pdf_iconv(ic, utf8_txt_1)
      assert_equal "???\x91\xd4???",
                   Redmine::Export::PDF::RDMPdfEncoding::rdm_pdf_iconv(ic, utf8_txt_2)
      assert_equal "??????\x91\xd4???",
                   Redmine::Export::PDF::RDMPdfEncoding::rdm_pdf_iconv(ic, utf8_txt_3)
    end
  end

  def test_rdm_pdf_iconv_cannot_convert_from_cp932
    set_language_if_valid 'ja'
    assert_equal 'CP932', l(:general_pdf_encoding)
    if RUBY_VERSION < '1.9'
      if RUBY_PLATFORM == 'java'
        ic = Iconv.new("UTF-8", 'SJIS')
      else
        ic = Iconv.new('UTF-8', l(:general_pdf_encoding))
      end
    end
    # \x90\xff : invalid CP932 character
    # \x91\xd4 :   valid CP932 character => \xe6\x85\x8b : valid UTF-8 character
    cp932_txt_1 = "\x90\xff\x91\xd4"
    cp932_txt_2 = "\x90\xff\x91\xd4\x90\xff"
    cp932_txt_3 = "\x90\xff\x90\xff\x91\xd4\x90\xff"
    if cp932_txt_1.respond_to?(:force_encoding)
      txt_1 = Redmine::Export::PDF::RDMPdfEncoding::rdm_pdf_iconv(ic, cp932_txt_1, true)
      txt_2 = Redmine::Export::PDF::RDMPdfEncoding::rdm_pdf_iconv(ic, cp932_txt_2, true)
      txt_3 = Redmine::Export::PDF::RDMPdfEncoding::rdm_pdf_iconv(ic, cp932_txt_3, true)
      assert_equal "ASCII-8BIT", cp932_txt_1.encoding.to_s
      assert_equal "ASCII-8BIT", cp932_txt_2.encoding.to_s
      assert_equal "ASCII-8BIT", cp932_txt_3.encoding.to_s
      assert_equal "UTF-8", txt_1.encoding.to_s
      assert_equal "UTF-8", txt_2.encoding.to_s
      assert_equal "UTF-8", txt_3.encoding.to_s
      assert_equal "??\xe6\x85\x8b", txt_1.force_encoding('ASCII-8BIT')
      assert_equal "??\xe6\x85\x8b??", txt_2.force_encoding('ASCII-8BIT')
      assert_equal "????\xe6\x85\x8b??", txt_3.force_encoding('ASCII-8BIT')
    elsif RUBY_PLATFORM == 'java'
      assert_equal "????",
                   Redmine::Export::PDF::RDMPdfEncoding::rdm_pdf_iconv(ic, cp932_txt_1, true)
      assert_equal "??????",
                   Redmine::Export::PDF::RDMPdfEncoding::rdm_pdf_iconv(ic, cp932_txt_2, true)
      assert_equal "????????",
                   Redmine::Export::PDF::RDMPdfEncoding::rdm_pdf_iconv(ic, cp932_txt_3, true)
    else
      assert_equal "??\xe6\x85\x8b",
                   Redmine::Export::PDF::RDMPdfEncoding::rdm_pdf_iconv(ic, cp932_txt_1, true)
      assert_equal "??\xe6\x85\x8b??",
                   Redmine::Export::PDF::RDMPdfEncoding::rdm_pdf_iconv(ic, cp932_txt_2, true)
      assert_equal "????\xe6\x85\x8b??",
                   Redmine::Export::PDF::RDMPdfEncoding::rdm_pdf_iconv(ic, cp932_txt_3, true)
    end
  end

  def test_rdm_pdf_iconv_invalid_utf8_should_be_replaced_en
    set_language_if_valid 'en'
    assert_equal 'UTF-8', l(:general_pdf_encoding)
    str1 = "Texte encod\xe9 en ISO-8859-1"
    str2 = "\xe9a\xe9b\xe9c\xe9d\xe9e test"
    str1.force_encoding("UTF-8") if str1.respond_to?(:force_encoding)
    str2.force_encoding("ASCII-8BIT") if str2.respond_to?(:force_encoding)
    if RUBY_VERSION < '1.9'
      ic = Iconv.new(l(:general_pdf_encoding), 'UTF-8')
    end
    txt_1 = Redmine::Export::PDF::RDMPdfEncoding::rdm_pdf_iconv(ic, str1)
    txt_2 = Redmine::Export::PDF::RDMPdfEncoding::rdm_pdf_iconv(ic, str2)
    txt_3 = Redmine::Export::PDF::RDMPdfEncoding::rdm_pdf_iconv(ic, str1, true)
    txt_4 = Redmine::Export::PDF::RDMPdfEncoding::rdm_pdf_iconv(ic, str2, true)
    if txt_1.respond_to?(:force_encoding)
      assert_equal "UTF-8", str1.encoding.to_s
      assert_equal "UTF-8", str2.encoding.to_s
      assert_equal "ASCII-8BIT", txt_1.encoding.to_s
      assert_equal "ASCII-8BIT", txt_2.encoding.to_s
      assert_equal "ASCII-8BIT", txt_3.encoding.to_s
      assert_equal "ASCII-8BIT", txt_4.encoding.to_s
    end
    assert_equal "Texte encod? en ISO-8859-1", txt_1
    assert_equal "?a?b?c?d?e test", txt_2
    assert_equal "Texte encod? en ISO-8859-1", txt_3
    assert_equal "?a?b?c?d?e test", txt_4
  end

  def test_rdm_pdf_iconv_invalid_utf8_should_be_replaced_ja
    set_language_if_valid 'ja'
    assert_equal 'CP932', l(:general_pdf_encoding)
    str1 = "Texte encod\xe9 en ISO-8859-1"
    str2 = "\xe9a\xe9b\xe9c\xe9d\xe9e test"
    str1.force_encoding("UTF-8") if str1.respond_to?(:force_encoding)
    str2.force_encoding("ASCII-8BIT") if str2.respond_to?(:force_encoding)
    if RUBY_VERSION < '1.9'
      if RUBY_PLATFORM == 'java'
        ic = Iconv.new("SJIS", 'UTF-8')
      else
        ic = Iconv.new(l(:general_pdf_encoding), 'UTF-8')
      end
    end
    txt_1 = Redmine::Export::PDF::RDMPdfEncoding::rdm_pdf_iconv(ic, str1)
    txt_2 = Redmine::Export::PDF::RDMPdfEncoding::rdm_pdf_iconv(ic, str2)
    if txt_1.respond_to?(:force_encoding)
      assert_equal "UTF-8", str1.encoding.to_s
      assert_equal "UTF-8", str2.encoding.to_s
      assert_equal "ASCII-8BIT", txt_1.encoding.to_s
      assert_equal "ASCII-8BIT", txt_2.encoding.to_s
    end
    assert_equal "Texte encod? en ISO-8859-1", txt_1
    assert_equal "?a?b?c?d?e test", txt_2
  end
end
