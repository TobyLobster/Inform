/***************************************************************************
 *                                                                         *
 * Copyright (C) 2006 by Mark J. Tilford                                   *
 *                                                                         *
 * This file is part of Geas.                                              *
 *                                                                         *
 * Geas is free software; you can redistribute it and/or modify            *
 * it under the terms of the GNU General Public License as published by    *
 * the Free Software Foundation; either version 2 of the License, or       *
 * (at your option) any later version.                                     *
 *                                                                         *
 * Geas is distributed in the hope that it will be useful,                 *
 * but WITHOUT ANY WARRANTY; without even the implied warranty of          *
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the           *
 * GNU General Public License for more details.                            *
 *                                                                         *
 * You should have received a copy of the GNU General Public License       *
 * along with Geas; if not, write to the Free Software                     *
 * Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
 *                                                                         *
 ***************************************************************************/

#include "VariableWidget.hh"
#include "general.hh"

using namespace std;

VariableWidget::VariableWidget()
{
  set_policy (Gtk::POLICY_AUTOMATIC, Gtk::POLICY_AUTOMATIC);

  m_refListStore = Gtk::ListStore::create (m_columns);
  
  m_TreeView.set_model (m_refListStore);

  m_TreeView.append_column ("Variable", m_columns.var);
  add (m_TreeView);
}

void VariableWidget::set_contents (const std::vector<std::string> &v)
{
  m_refListStore->clear();
  for (uint i = 0; i < v.size(); i ++)
    {
      Gtk::TreeModel::Row row = *(m_refListStore->append());
      row[m_columns.var] = v[i];
    }
}
