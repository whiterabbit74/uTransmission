// This file Copyright © Mnemosyne LLC.
// It may be used under GPLv2 (SPDX: GPL-2.0-only), GPLv3 (SPDX: GPL-3.0-only),
// or any future license endorsed by Mnemosyne LLC.
// License text can be found in the licenses/ folder.

#include "Sidebar.h"

#include <optional>

#include <QHeaderView>

#include "Filters.h"
#include "NativeIcon.h"
#include "Prefs.h"
#include "TorrentFilter.h"
#include "TorrentModel.h"

namespace
{

auto constexpr ActivityRole = Qt::UserRole;

} // namespace

Sidebar::Sidebar(Prefs& prefs, TorrentModel const& torrents, TorrentFilter const& filter, QWidget* parent)
    : QTreeWidget{ parent }
    , prefs_{ prefs }
    , torrents_{ torrents }
    , filter_{ filter }
    , is_bootstrapping_{ true }
{
    setColumnCount(2);
    setHeaderHidden(true);
    setRootIsDecorated(false);
    setIndentation(0);
    setUniformRowHeights(true);
    setSelectionMode(QAbstractItemView::SingleSelection);
    header()->setStretchLastSection(false);
    header()->setSectionResizeMode(0, QHeaderView::Stretch);
    header()->setSectionResizeMode(1, QHeaderView::ResizeToContents);

    auto const add_row = [this](ShowMode const show_mode, QString const& label, std::optional<icons::Type> const type)
    {
        auto* const item = new QTreeWidgetItem{ this };
        item->setText(0, label);
        item->setData(0, ActivityRole, QVariant::fromValue(show_mode));
        item->setTextAlignment(1, Qt::AlignRight | Qt::AlignVCenter);

        if (type)
        {
            item->setIcon(0, icons::icon(*type));
        }
    };

    add_row(ShowMode::ShowAll, tr("All"), {});
    add_row(ShowMode::ShowActive, tr("Active"), icons::Type::TorrentStateActive);
    add_row(ShowMode::ShowDownloading, tr("Downloading"), icons::Type::TorrentStateDownloading);
    add_row(ShowMode::ShowSeeding, tr("Seeding"), icons::Type::TorrentStateSeeding);
    add_row(ShowMode::ShowPaused, tr("Paused"), icons::Type::TorrentStatePaused);
    add_row(ShowMode::ShowFinished, tr("Finished"), {});
    add_row(ShowMode::ShowVerifying, tr("Verifying"), icons::Type::TorrentStateVerifying);
    add_row(ShowMode::ShowError, tr("Error"), icons::Type::TorrentStateError);

    connect(&prefs_, &Prefs::changed, this, &Sidebar::refreshPref);
    connect(&recount_timer_, &QTimer::timeout, this, &Sidebar::recount);
    connect(&torrents_, &TorrentModel::modelReset, this, &Sidebar::recountSoon);
    connect(&torrents_, &TorrentModel::rowsInserted, this, &Sidebar::recountSoon);
    connect(&torrents_, &TorrentModel::rowsRemoved, this, &Sidebar::recountSoon);
    connect(&torrents_, &TorrentModel::torrentsChanged, this, &Sidebar::onTorrentsChanged);
    connect(this, &QTreeWidget::itemSelectionChanged, this, &Sidebar::onSelectionChanged);

    recount();
    is_bootstrapping_ = false; // NOLINT cppcoreguidelines-prefer-member-initializer

    // keep the labels from being squeezed into ellipses by the splitter
    setMinimumWidth(sizeHintForColumn(0) + sizeHintForColumn(1) + (2 * frameWidth()) + 12);

    refreshPref(Prefs::FILTER_MODE);
}

void Sidebar::recount()
{
    auto const torrents_per_mode = filter_.countTorrentsPerMode();

    for (int row = 0, n = topLevelItemCount(); row < n; ++row)
    {
        auto* const item = topLevelItem(row);
        auto const show_mode = item->data(0, ActivityRole).value<ShowMode>();
        item->setText(1, QStringLiteral("%L1").arg(torrents_per_mode[static_cast<int>(show_mode)]));
    }
}

void Sidebar::recountSoon()
{
    if (!recount_timer_.isActive())
    {
        recount_timer_.setSingleShot(true);
        recount_timer_.start(800);
    }
}

void Sidebar::refreshPref(int key)
{
    if (key != Prefs::FILTER_MODE)
    {
        return;
    }

    auto const show_mode = prefs_.get<ShowMode>(key);

    for (int row = 0, n = topLevelItemCount(); row < n; ++row)
    {
        auto* const item = topLevelItem(row);

        if (item->data(0, ActivityRole).value<ShowMode>() == show_mode)
        {
            auto const was_bootstrapping = is_bootstrapping_;
            is_bootstrapping_ = true;
            setCurrentItem(item);
            is_bootstrapping_ = was_bootstrapping;
            break;
        }
    }
}

void Sidebar::onSelectionChanged()
{
    auto const* const item = currentItem();

    if (!is_bootstrapping_ && item != nullptr)
    {
        prefs_.set(Prefs::FILTER_MODE, item->data(0, ActivityRole).value<ShowMode>());
    }
}

void Sidebar::onTorrentsChanged(torrent_ids_t const& ids, Torrent::fields_t const& changed_fields)
{
    Q_UNUSED(ids)

    if ((changed_fields & ShowModeFields).any())
    {
        recountSoon();
    }
}
