//
//  MainViewController.swift
//  CollectionDiffGameDB
//
//  Created by Alfian Losari on 19/06/19.
//  Copyright © 2019 Alfian Losari. All rights reserved.
//

import UIKit
import IGDB_SWIFT_API

class MainViewController: UIViewController {
    
    lazy var gameService: IGDBWrapper = {
        $0.userKey = "YOUR_IGDB_API_KEY"
        return $0
    }(IGDBWrapper())
    
    var games = [Proto_Game]()
    var sections: [SectionLayoutKind] = []
    var selectedPlatforms: Set<PlatformType> = []
    var selectedGenres: Set<GenreType> = []
    var selectedSort: SortType = .popularity
    
    let searchController = UISearchController(searchResultsController: nil)
    var collectionView: UICollectionView! = nil
    var dataSource: UICollectionViewDiffableDataSource<SectionLayoutKind, Item>! = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Popular GameDB UI Diffing"
        configureCollectionView()
        configureDataSource()
        configureSearchController()
    
        loadGames()
    }
    
    private func loadGames() {
        gameService.apiRequest(endpoint: .GAMES, apicalypseQuery: "fields name, first_release_date, id, popularity, rating, genres.id, platforms.id, cover.image_id; where (platforms = (\(PlatformType.apocalypseFilterText)) & genres = (\(GenreType.apocalypseFilterText)) & popularity >= 80 & themes != 42); sort popularity desc; limit 10;", dataResponse: { bytes in
            guard let gameResults = try? Proto_GameResult(serializedData: bytes) else {
                return
            }
            DispatchQueue.main.async { [weak self] in
                self?.navigationItem.titleView = self?.searchController.searchBar
                self?.games = gameResults.games.sorted { $0.name < $1.name }
                self?.updateUI()
            }
        }, errorResponse: { error in
            print(error.localizedDescription)
        })
    }
    
    private func configureSearchController() {
        searchController.searchResultsUpdater = self
        searchController.showsSearchResultsController = false
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.delegate = self
        searchController.hidesNavigationBarDuringPresentation = false
    }
    
    private func configureCollectionView() {
        let collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: createLayout())
        view.addSubview(collectionView)
        collectionView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        collectionView.backgroundColor = .systemBackground
        
        collectionView.register(UINib(nibName: "BadgeItemCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "BadgeItemCollectionViewCell")
        collectionView.register(UINib(nibName: "GameCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "GameCollectionViewCell")
        collectionView.delegate = self
        self.collectionView = collectionView
    }

    private func createLayout() -> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout { (sectionIndex: Int,
            layoutEnvironment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection? in
            guard !self.sections.isEmpty else { return nil }
            let sectionLayoutKind = self.sections[sectionIndex]
            
            switch sectionLayoutKind.kind {
            case is CarouselPlatform, is CarouselGenres, is CarouselSorts:
                let itemSize = NSCollectionLayoutSize(widthDimension: .estimated(150), heightDimension: .fractionalHeight(1.0))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                
                let groupSize = NSCollectionLayoutSize(widthDimension: .estimated(150),
                                                       heightDimension: .absolute(44))
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
                group.interItemSpacing = .fixed(8)
                
                let section = NSCollectionLayoutSection(group: group)
                section.orthogonalScrollingBehavior = .continuous
                section.interGroupSpacing = 8
                section.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 20, bottom: 0, trailing: 20)
                
                return section
                
            case is Grid:
                let imageWidth: CGFloat = 150
                let ratioMultiplier = 200.0 / imageWidth
                let containerWidth = layoutEnvironment.container.effectiveContentSize.width

                let itemCount = containerWidth / imageWidth
                let itemWidth = imageWidth * (itemCount / ceil(itemCount))
                let itemHeight = ratioMultiplier * itemWidth
                let itemSize = NSCollectionLayoutSize(widthDimension: .absolute(itemWidth),
                                                      heightDimension: .absolute(itemHeight))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                                       heightDimension: .absolute(itemHeight))
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize,
                                                               subitems: [item])
                
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 0, bottom: 0, trailing: 0)
                return section
                
            default:
                return nil
            }
        }
        return layout
    }
    
    private func configureDataSource() {
        dataSource = UICollectionViewDiffableDataSource<SectionLayoutKind, Item>(collectionView: collectionView, cellProvider: { (collectionView, indexPath, item) -> UICollectionViewCell? in
            switch item.itemType {
            case .platform(let type as CustomStringConvertible, let isSelected),
                 .genre(let type as CustomStringConvertible, let isSelected),
                 .sort(let type as CustomStringConvertible, let isSelected):
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "BadgeItemCollectionViewCell", for: indexPath) as! BadgeItemCollectionViewCell
                cell.configure(text: type.description, isSelected: isSelected)
                return cell
                
            case .game(let game):
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "GameCollectionViewCell", for: indexPath) as! GameCollectionViewCell
                cell.configure(game)
                return cell
            }
        })
        
        let snapshot =  createSnapshot()
        dataSource.apply(snapshot, animatingDifferences: false)
    }
    
    private func updateUI() {
        let snapshot =  createSnapshot()
        dataSource.apply(snapshot, animatingDifferences: true)
    }
    
    private func createSnapshot() -> NSDiffableDataSourceSnapshot<SectionLayoutKind, Item> {
        let snapshot = NSDiffableDataSourceSnapshot<SectionLayoutKind, Item>()
        var sections = [SectionLayoutKind]()
        
        let genreLayoutKind = calculateGenresSectionLayoutKind()
        snapshot.appendSections([genreLayoutKind])
        snapshot.appendItems(genreLayoutKind.kind.items)
        sections.append(genreLayoutKind)

        let platformLayoutKind = calculatePlatformsSectionLayoutKind()
        snapshot.appendSections([platformLayoutKind])
        snapshot.appendItems(platformLayoutKind.kind.items)
        sections.append(platformLayoutKind)

        let sortLayoutKind = calculateSortsSectionLayoutKind()
        snapshot.appendSections([sortLayoutKind])
        snapshot.appendItems(sortLayoutKind.kind.items)
        sections.append(sortLayoutKind)

        let gameLayoutKind = calculateGamesSectionLayoutKind()
        snapshot.appendSections([gameLayoutKind])
        snapshot.appendItems(gameLayoutKind.kind.items)
        sections.append(gameLayoutKind)
        
        self.sections = sections
        return snapshot
    }
    
    private func calculateGenresSectionLayoutKind() -> SectionLayoutKind {
        let genres = GenreType.allCases.map { (g) -> Item in
            let isSelected: Bool
            switch g {
            case .all:
                isSelected = self.selectedGenres.isEmpty ? true : false
            default:
                isSelected = self.selectedGenres.contains(g)
            }
            return Item(itemType: .genre(type: g, isSelected: isSelected))
        }
        return SectionLayoutKind(kind: CarouselGenres(items: genres))
    }
    
    private func calculatePlatformsSectionLayoutKind() -> SectionLayoutKind {
        let platforms = PlatformType.allCases.map { (p) -> Item in
            let isSelected: Bool
            switch p {
            case .all:
                isSelected = self.selectedPlatforms.isEmpty ? true : false
            default:
                isSelected = self.selectedPlatforms.contains(p)
            }
            return Item(itemType: .platform(type: p, isSelected: isSelected))
        }
        return SectionLayoutKind(kind: CarouselPlatform(items: platforms))
    }
    
    private func calculateSortsSectionLayoutKind() -> SectionLayoutKind {
        let sorts = SortType.allCases.map { (s) -> Item in
            let isSelected = self.selectedSort == s
            return Item(itemType: .sort(type: s, isSelected: isSelected))
        }
        return SectionLayoutKind(kind: CarouselSorts(items: sorts))
    }
    
    private func calculateGamesSectionLayoutKind() -> SectionLayoutKind {
        var games: [Proto_Game]

        let searchText = (searchController.searchBar.text ?? "").lowercased()
        if searchText.isEmpty {
            games = self.games
        } else {
            games = self.games.filter { $0.name.lowercased().contains(searchText) }.sorted { $0.name < $1.name }
        }
        
        if selectedPlatforms.count > 0 {
            let selectedPlatformIds = self.selectedPlatforms.map { $0.id }
            games = games.filter({ (game) -> Bool in
                let platformIds = Set(game.platforms.map { Int($0.id) })
                return platformIds.intersection(selectedPlatformIds).count > 0
            })
        }
        
        if selectedGenres.count > 0 {
            let selectedGenreIds = self.selectedGenres.map { $0.id }
            games = games.filter({ (game) -> Bool in
                let genreIds = Set(game.genres.map { Int($0.id) })
                return genreIds.intersection(selectedGenreIds).count > 0
            })
        }
        
        switch selectedSort {
        case .popularity:
            games.sort { $0.popularity > $1.popularity }
        case .rating:
            games.sort { $0.rating > $1.rating }
        case .releaseDate:
            games.sort { $0.firstReleaseDate.date > $1.firstReleaseDate.date }
        }
        return SectionLayoutKind(kind: Grid(items: games.map { Item(itemType: .game($0))}))
    }
    
}

extension MainViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let item = dataSource.itemIdentifier(for: indexPath) else {
            return
        }
        
        switch item.itemType {
        case .platform(let platform, let isSelected):
            switch platform {
            case .all:
                selectedPlatforms = []
            default:
                if isSelected {
                    selectedPlatforms.remove(platform)
                } else {
                    selectedPlatforms.insert(platform)
                }
            }
            
        case .genre(let genre, let isSelected):
            switch(genre) {
            case .all:
                selectedGenres = []
            default:
                if isSelected {
                    selectedGenres.remove(genre)
                } else {
                    selectedGenres.insert(genre)
                }
            }
            
        case .sort(let sort, _):
            selectedSort = sort
    
        default:
            return
        }
        updateUI()
    }
}

extension MainViewController: UISearchResultsUpdating, UISearchBarDelegate {
   
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
    
    func updateSearchResults(for searchController: UISearchController) {
        updateUI()
    }
}
