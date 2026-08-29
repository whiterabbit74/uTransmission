// This file Copyright © Mnemosyne LLC.
// It may be used under GPLv2 (SPDX: GPL-2.0-only), GPLv3 (SPDX: GPL-3.0-only),
// or any future license endorsed by Mnemosyne LLC.
// License text can be found in the licenses/ folder.

#pragma once

#include <QTimer>
#include <QTreeWidget>

#include "Torrent.h"
#include "Typedefs.h"

class Prefs;
class TorrentFilter;
class TorrentModel;

class Sidebar : public QTreeWidget
{
    Q_OBJECT

public:
    Sidebar(Prefs& prefs, TorrentModel const& torrents, TorrentFilter const& filter, QWidget* parent = nullptr);
    Sidebar(Sidebar&&) = delete;
    Sidebar(Sidebar const&) = delete;
    Sidebar& operator=(Sidebar&&) = delete;
    Sidebar& operator=(Sidebar const&) = delete;

private slots:
    void recount();
    void recountSoon();
    void refreshPref(int key);
    void onSelectionChanged();
    void onTorrentsChanged(torrent_ids_t const&, Torrent::fields_t const& fields);

private:
    Prefs& prefs_;
    TorrentModel const& torrents_;
    TorrentFilter const& filter_;

    QTimer recount_timer_;
    bool is_bootstrapping_ = {};
};
