import { useCallback, useEffect, useMemo, useState } from 'react'
import './App.css'
import { apiRequest } from './lib/api'
import { supabase } from './lib/supabase'

const statDefinitions = [
  { label: 'Total Laporan', tone: 'blue', filter: 'all' },
  { label: 'Menunggu', tone: 'gray', filter: 'pending' },
  { label: 'Antrean', tone: 'slate', filter: 'queued' },
  { label: 'Diproses', tone: 'yellow', filter: 'in_progress' },
  { label: 'Selesai', tone: 'green', filter: 'resolved' },
  { label: 'Ditolak', tone: 'red', filter: 'rejected' },
  { label: 'Prioritas High', tone: 'danger', filter: 'High' },
]

const menuItems = [
  ['D', 'Dashboard'],
  ['L', 'Data Laporan'],
  ['K', 'Kategori Laporan'],
  ['T', 'Peta Laporan'],
  ['G', 'Statistik'],
  ['A', 'Data Admin'],
  ['P', 'Pengaturan'],
]

const categoryMenuItems = [
  ['J', 'Jalan Berlubang'],
  ['L', 'Lampu Jalan Mati'],
  ['R', 'Rambu Rusak'],
  ['T', 'Trotoar Rusak'],
  ['K', 'Kemacetan/Penghalang Jalan'],
  ['D', 'Drainase Tersumbat'],
  ['A', 'Lampu Lalu Lintas Rusak'],
  ['M', 'Marka Jalan Pudar'],
  ['P', 'Jembatan/Pagar Pengaman Rusak'],
  ['O', 'Lainnya'],
]

const adminSettings = [
  'Melihat semua laporan masuk',
  'Verifikasi laporan',
  'Ubah status laporan',
  'Menentukan prioritas',
  'Melihat laporan berdasarkan kategori',
  'Melihat laporan berdasarkan tingkat kerusakan',
  'Melihat titik laporan di peta',
]

const formatDate = (date) =>
  new Intl.DateTimeFormat('id-ID', {
    day: 'numeric',
    month: 'long',
    year: 'numeric',
  }).format(date)

const categories = [
  ['Jalan Berlubang', 'Lubang kecil', 'Lubang sedang', 'Lubang besar'],
  ['Lampu Jalan Mati', 'Lampu mati', 'Lampu redup', 'Lampu berkedip'],
  ['Rambu Rusak', 'Rambu hilang', 'Rambu roboh', 'Rambu tidak terlihat'],
  ['Trotoar Rusak', 'Trotoar retak', 'Trotoar berlubang', 'Akses tidak aman'],
  ['Kemacetan/Penghalang Jalan', 'Hambatan jalan', 'Parkir liar', 'Macet berat'],
  ['Drainase Tersumbat', 'Selokan tersumbat', 'Air meluap', 'Saluran rusak'],
  ['Lampu Lalu Lintas Rusak', 'Traffic light mati', 'Lampu tidak sinkron'],
  ['Marka Jalan Pudar', 'Marka hilang', 'Zebra cross pudar'],
  ['Jembatan/Pagar Pengaman Rusak', 'Pagar rusak', 'Pembatas jalan rusak'],
  ['Lainnya', 'Kategori lain yang perlu pemeriksaan petugas'],
]

const priorities = [
  {
    level: 'LOW',
    tone: 'low',
    condition: 'Tidak membahayakan dan masih bisa digunakan.',
    example: 'Retak kecil, lampu redup, sampah sedikit.',
    target: '<= 30 Hari',
  },
  {
    level: 'MID',
    tone: 'mid',
    condition: 'Mengganggu aktivitas warga dan berpotensi membesar.',
    example: 'Lubang sedang, pohon miring, drainase tersumbat.',
    target: '<= 14 Hari',
  },
  {
    level: 'HIGH',
    tone: 'high',
    condition: 'Berbahaya dan memiliki risiko kecelakaan.',
    example: 'Jalan amblas, pohon hampir tumbang, kabel terbuka, banjir besar.',
    target: '<= 7 Hari',
  },
]

const categoryColors = {
  'Jalan Berlubang': '#3b82f6',
  'Lampu Jalan Mati': '#f59e0b',
  'Rambu Rusak': '#ef4444',
  'Trotoar Rusak': '#22c55e',
  'Kemacetan/Penghalang Jalan': '#8b5cf6',
  'Drainase Tersumbat': '#06b6d4',
  'Lampu Lalu Lintas Rusak': '#f97316',
  'Marka Jalan Pudar': '#14b8a6',
  'Jembatan/Pagar Pengaman Rusak': '#a855f7',
  Lainnya: '#64748b',
}

const levelColors = {
  Low: '#22c55e',
  Mid: '#f59e0b',
  High: '#ef4444',
}

const categoryNames = [
  'Jalan Berlubang',
  'Lampu Jalan Mati',
  'Rambu Rusak',
  'Trotoar Rusak',
  'Kemacetan/Penghalang Jalan',
  'Drainase Tersumbat',
  'Lampu Lalu Lintas Rusak',
  'Marka Jalan Pudar',
  'Jembatan/Pagar Pengaman Rusak',
  'Lainnya',
]

const statusLabels = {
  pending: 'Menunggu',
  queued: 'Antrean',
  accepted: 'Diterima',
  rejected: 'Ditolak',
  in_progress: 'Diproses',
  resolved: 'Selesai',
  suspected_spam: 'Dugaan Spam',
}

const statusOptions = [
  ['pending', 'Menunggu'],
  ['queued', 'Antrean'],
  ['accepted', 'Diterima'],
  ['in_progress', 'Diproses'],
  ['resolved', 'Selesai'],
  ['rejected', 'Ditolak'],
  ['suspected_spam', 'Dugaan Spam'],
]

const statusClassNames = {
  pending: 'pending',
  queued: 'queued',
  accepted: 'accepted',
  rejected: 'rejected',
  in_progress: 'in-progress',
  resolved: 'resolved',
  suspected_spam: 'suspected-spam',
}

const statusLabel = (status) => statusLabels[status] || status
const statusClassName = (status) => statusClassNames[status] || 'pending'
const coordinateLabel = (latitude, longitude) =>
  `${Number(latitude).toFixed(5)}, ${Number(longitude).toFixed(5)}`

const formatLocationName = (location) => {
  const address = location.address || {}
  const road = address.road || address.neighbourhood || address.suburb
  const city =
    address.city || address.town || address.village || address.county || address.state

  if (road && city) return `${road}, ${city}`
  if (location.name && city) return `${location.name}, ${city}`
  return location.display_name || ''
}

const reverseGeocodeReport = async (report) => {
  const params = new URLSearchParams({
    format: 'jsonv2',
    lat: String(report.latitude),
    lon: String(report.longitude),
    zoom: '18',
    addressdetails: '1',
  })
  const response = await fetch(
    `https://nominatim.openstreetmap.org/reverse?${params.toString()}`,
  )

  if (!response.ok) return null

  const data = await response.json()
  return formatLocationName(data)
}

const searchMapLocations = async (query) => {
  const params = new URLSearchParams({
    format: 'jsonv2',
    q: query,
    countrycodes: 'id',
    addressdetails: '1',
    limit: '5',
  })
  const response = await fetch(
    `https://nominatim.openstreetmap.org/search?${params.toString()}`,
  )

  if (!response.ok) return []

  const data = await response.json()
  return data
    .map((item) => ({
      id: item.place_id,
      label: formatLocationName(item),
      latitude: Number(item.lat),
      longitude: Number(item.lon),
    }))
    .filter((item) => item.label && Number.isFinite(item.latitude))
}

const mapBackendReport = (report) => ({
  id: report.id,
  latitude: Number(report.latitude),
  longitude: Number(report.longitude),
  location: coordinateLabel(report.latitude, report.longitude),
  locationName: '',
  locationResolved: false,
  mapQuery: `${report.latitude},${report.longitude}`,
  category: report.category_name,
  group: report.category_name,
  level: report.flag_count > 0 ? 'High' : report.is_suspected_spam ? 'Mid' : 'Low',
  status: report.status,
  date: formatDate(new Date(report.created_at)),
  dateISO: report.created_at?.slice(0, 10) || '',
  description: report.description,
  photoUrl: report.photo_url,
  resolutionProofPhotoUrl: report.resolution_proof_photo_url,
  resolutionNote: report.resolution_note,
  resolvedAt: report.resolved_at,
  reporterName: report.reporter_name,
  commentCount: report.comment_count ?? 0,
  upvoteCount: report.upvote_count ?? 0,
  flagCount: report.flag_count ?? 0,
})

const mapZoom = 13
const tileSize = 256
const fallbackMapCenter = { latitude: -2.5489, longitude: 118.0149 }
const mapTileOffsets = [-2, -1, 0, 1, 2]

const projectToPixel = ({ latitude, longitude }, zoom = mapZoom) => {
  const sinLatitude = Math.sin((latitude * Math.PI) / 180)
  const clampedSinLatitude = Math.min(Math.max(sinLatitude, -0.9999), 0.9999)
  const scale = tileSize * 2 ** zoom

  return {
    x: ((longitude + 180) / 360) * scale,
    y:
      (0.5 -
        Math.log((1 + clampedSinLatitude) / (1 - clampedSinLatitude)) /
          (4 * Math.PI)) *
      scale,
  }
}

function AdminReportMap({ reports, selectedReport, searchCenter, onSelectReport }) {
  const center = selectedReport || searchCenter || reports[0] || fallbackMapCenter
  const centerPixel = projectToPixel(center)
  const centerTile = {
    x: Math.floor(centerPixel.x / tileSize),
    y: Math.floor(centerPixel.y / tileSize),
  }
  const centerOffset = {
    x: centerPixel.x - centerTile.x * tileSize,
    y: centerPixel.y - centerTile.y * tileSize,
  }

  return (
    <div className="admin-osm-map">
      <div className="tile-layer" aria-hidden="true">
        {mapTileOffsets.flatMap((offsetY) =>
          mapTileOffsets.map((offsetX) => {
            const tileX = centerTile.x + offsetX
            const tileY = centerTile.y + offsetY
            const tileKey = `${tileX}-${tileY}`

            return (
              <img
                alt=""
                draggable="false"
                key={tileKey}
                src={`https://tile.openstreetmap.org/${mapZoom}/${tileX}/${tileY}.png`}
                style={{
                  left: `calc(50% + ${offsetX * tileSize - centerOffset.x}px)`,
                  top: `calc(50% + ${offsetY * tileSize - centerOffset.y}px)`,
                }}
              />
            )
          }),
        )}
      </div>

      <div className="marker-layer">
        {reports.map((report) => {
          const reportPixel = projectToPixel(report)
          const isSelected = report.id === selectedReport?.id

          return (
            <button
              aria-label={`Pilih laporan ${report.category}`}
              className={`map-marker ${statusClassName(report.status)} ${
                isSelected ? 'selected' : ''
              }`}
              key={report.id}
              onClick={() => onSelectReport(report.id)}
              style={{
                left: `calc(50% + ${reportPixel.x - centerPixel.x}px)`,
                top: `calc(50% + ${reportPixel.y - centerPixel.y}px)`,
              }}
              title={`${report.category} - ${statusLabel(report.status)}`}
              type="button"
            >
              !
            </button>
          )
        })}
        {searchCenter ? (
          <span
            className="map-search-pin"
            style={{ left: '50%', top: '50%' }}
            title={searchCenter.label}
          />
        ) : null}
      </div>
    </div>
  )
}

const monthlyReports = [
  ['Jan', 80],
  ['Feb', 120],
  ['Mar', 180],
  ['Apr', 150],
]

function DonutChart({ title, total, segments }) {
  const gradientParts = segments.reduce(
    (result, [, percent, color]) => {
      const value = Number(percent.replace('%', ''))
      return {
        start: result.start + value,
        parts: [
          ...result.parts,
          `${color} ${result.start}% ${result.start + value}%`,
        ],
      }
    },
    { start: 0, parts: [] },
  )
  const gradient = gradientParts.parts.join(', ')

  return (
    <article className="panel chart-card">
      <header className="panel-heading">
        <h2>{title}</h2>
        <span>Total {total}</span>
      </header>
      <div className="donut-wrap">
        <div
          className="donut"
          style={{ background: `conic-gradient(${gradient})` }}
        >
          <span>
            Total
            <strong>{total}</strong>
          </span>
        </div>
        <div className="legend-list">
          {segments.map(([label, percent, color]) => (
            <div key={label}>
              <i style={{ backgroundColor: color }} />
              <span>{label}</span>
              <strong>{percent}</strong>
            </div>
          ))}
        </div>
      </div>
    </article>
  )
}

function App() {
  const [isLoggedIn, setIsLoggedIn] = useState(false)
  const [session, setSession] = useState(null)
  const [adminUser, setAdminUser] = useState(null)
  const [loginForm, setLoginForm] = useState({ email: '', password: '' })
  const [loginError, setLoginError] = useState('')
  const [isLoginLoading, setIsLoginLoading] = useState(false)
  const [isLoadingData, setIsLoadingData] = useState(false)
  const [dataError, setDataError] = useState('')
  const [dashboardStats, setDashboardStats] = useState(null)
  const [reports, setReports] = useState([])
  const [activeFilter, setActiveFilter] = useState('all')
  const [activeMenu, setActiveMenu] = useState('Dashboard')
  const [isCategoryOpen, setIsCategoryOpen] = useState(false)
  const [search, setSearch] = useState('')
  const [sortDate, setSortDate] = useState('newest')
  const [selectedReportId, setSelectedReportId] = useState('')
  const [dateFilter, setDateFilter] = useState({ start: '', end: '' })
  const [mapSearch, setMapSearch] = useState('')
  const [mapSearchResults, setMapSearchResults] = useState([])
  const [mapSearchCenter, setMapSearchCenter] = useState(null)
  const [isMapSearching, setIsMapSearching] = useState(false)
  const [mapSearchError, setMapSearchError] = useState('')
  const [resolveDraft, setResolveDraft] = useState(null)
  const [resolveProofFile, setResolveProofFile] = useState(null)
  const [resolveNote, setResolveNote] = useState('')
  const [isResolving, setIsResolving] = useState(false)
  const [resolveError, setResolveError] = useState('')

  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => {
      if (data.session) {
        setSession(data.session)
        setAdminUser(data.session.user)
        setIsLoggedIn(true)
      }
    })

    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange((_, nextSession) => {
      setSession(nextSession)
      setAdminUser(nextSession?.user ?? null)
      setIsLoggedIn(Boolean(nextSession))
    })

    return () => subscription.unsubscribe()
  }, [])

  const selectedReport =
    reports.find((report) => report.id === selectedReportId) || reports[0] || null
  const activeMapReport = selectedReportId ? selectedReport : null

  const dateFilteredReports = useMemo(
    () =>
      reports.filter((report) => {
        const matchesStart =
          !dateFilter.start || report.dateISO >= dateFilter.start
        const matchesEnd = !dateFilter.end || report.dateISO <= dateFilter.end

        return matchesStart && matchesEnd
      }),
    [dateFilter.end, dateFilter.start, reports],
  )

  const hasReports = dateFilteredReports.length > 0

  const stats = useMemo(
    () => {
      const backendCounts = {
        all: dashboardStats?.total_reports,
        pending: dashboardStats?.pending_reports,
        queued: dashboardStats?.queued_reports,
        accepted: dashboardStats?.accepted_reports,
        in_progress: dashboardStats?.in_progress_reports,
        resolved: dashboardStats?.resolved_reports,
        rejected: dashboardStats?.rejected_reports,
      }

      return statDefinitions.map((stat) => {
        const hasDateFilter = dateFilter.start || dateFilter.end
        const value = !hasDateFilter && backendCounts[stat.filter] !== undefined ? (
          backendCounts[stat.filter]
        ) : (
          stat.filter === 'all'
            ? dateFilteredReports.length
            : dateFilteredReports.filter(
              (report) =>
                report.status === stat.filter || report.level === stat.filter,
            ).length
        )

        return { ...stat, value: value.toString() }
      })
    },
    [dashboardStats, dateFilter.end, dateFilter.start, dateFilteredReports],
  )

  const categoryChart = useMemo(
    () =>
      categoryNames.map((category) => {
        const count = dateFilteredReports.filter(
          (report) => report.group === category,
        ).length
        const percent = hasReports
          ? Math.round((count / dateFilteredReports.length) * 100)
          : 0
        return [category, `${percent}%`, categoryColors[category]]
      }),
    [dateFilteredReports, hasReports],
  )

  const levelChart = useMemo(
    () =>
      ['Low', 'Mid', 'High'].map((level) => {
        const count = dateFilteredReports.filter(
          (report) => report.level === level,
        ).length
        const percent = hasReports
          ? Math.round((count / dateFilteredReports.length) * 100)
          : 0
        return [level, `${percent}%`, levelColors[level]]
      }),
    [dateFilteredReports, hasReports],
  )

  const filteredReports = useMemo(() => {
    const query = search.toLowerCase()

    return dateFilteredReports
      .filter((report) => {
        const matchesSearch =
          report.id.toLowerCase().includes(query) ||
          report.location.toLowerCase().includes(query) ||
          report.locationName.toLowerCase().includes(query) ||
          report.category.toLowerCase().includes(query) ||
          report.group.toLowerCase().includes(query) ||
          report.status.toLowerCase().includes(query) ||
          report.date.toLowerCase().includes(query) ||
          report.level.toLowerCase().includes(query)

        const matchesFilter =
          activeFilter === 'all' ||
          report.status === activeFilter ||
          report.level === activeFilter ||
          report.group === activeFilter

        return matchesSearch && matchesFilter
      })
      .toSorted((firstReport, secondReport) => {
        if (sortDate === 'oldest') {
          return firstReport.dateISO.localeCompare(secondReport.dateISO)
        }

    return secondReport.dateISO.localeCompare(firstReport.dateISO)
      })
  }, [activeFilter, dateFilteredReports, search, sortDate])

  useEffect(() => {
    const unresolvedReports = reports.filter((report) => !report.locationResolved)
    if (unresolvedReports.length === 0) return

    let isCancelled = false
    const timeoutId = window.setTimeout(async () => {
      const resolvedReports = []

      for (const report of unresolvedReports) {
        if (isCancelled) return

        try {
          const locationName = await reverseGeocodeReport(report)
          resolvedReports.push({
            id: report.id,
            locationName: locationName || report.location,
          })
        } catch {
          resolvedReports.push({ id: report.id, locationName: report.location })
        }
      }

      if (isCancelled) return

      setReports((currentReports) =>
        currentReports.map((report) => {
          const resolved = resolvedReports.find((item) => item.id === report.id)
          if (!resolved) return report

          return {
            ...report,
            locationName: resolved.locationName,
            locationResolved: true,
          }
        }),
      )
    }, 300)

    return () => {
      isCancelled = true
      window.clearTimeout(timeoutId)
    }
  }, [reports])

  const encodedMapQuery = encodeURIComponent(
    activeMapReport?.mapQuery ||
      (mapSearchCenter
        ? coordinateLabel(mapSearchCenter.latitude, mapSearchCenter.longitude)
        : selectedReport?.mapQuery || selectedReport?.location || 'Indonesia'),
  )
  const mapSearchUrl = `https://www.google.com/maps/search/?api=1&query=${encodedMapQuery}`

  const openReportList = (filter, menuLabel = 'Data Laporan') => {
    setActiveFilter(filter)
    setActiveMenu(menuLabel)
    window.requestAnimationFrame(() => {
      document.getElementById('data-laporan')?.scrollIntoView({
        behavior: 'smooth',
        block: 'start',
      })
    })
  }

  const openPanel = (elementId, menuLabel) => {
    setActiveMenu(menuLabel)
    window.requestAnimationFrame(() => {
      document.getElementById(elementId)?.scrollIntoView({
        behavior: 'smooth',
        block: 'start',
      })
    })
  }

  const loadAdminData = useCallback(async (token) => {
    if (!token) return

    setIsLoadingData(true)
    setDataError('')

    try {
      const [dashboard, reportResponse] = await Promise.all([
        apiRequest('/admin/dashboard', token),
        apiRequest('/admin/reports?limit=100', token),
      ])
      const nextReports = (reportResponse?.data ?? []).map(mapBackendReport)

      setDashboardStats(dashboard)
      setReports(nextReports)
      setSelectedReportId((currentId) => {
        if (nextReports.some((report) => report.id === currentId)) {
          return currentId
        }
        return nextReports[0]?.id ?? ''
      })
    } catch (error) {
      setReports([])
      setSelectedReportId('')
      setDataError(error.message)
    } finally {
      setIsLoadingData(false)
    }
  }, [])

  useEffect(() => {
    if (!session?.access_token) return
    const timeoutId = window.setTimeout(() => {
      loadAdminData(session.access_token)
    }, 0)
    const intervalId = window.setInterval(() => {
      loadAdminData(session.access_token)
    }, 15000)

    return () => {
      window.clearTimeout(timeoutId)
      window.clearInterval(intervalId)
    }
  }, [loadAdminData, session?.access_token])

  const updateStatus = async (reportId, status) => {
    if (status === 'resolved') {
      const report = reports.find((item) => item.id === reportId)
      if (report) {
        setResolveDraft(report)
        setResolveProofFile(null)
        setResolveNote('')
        setResolveError('')
      }
      return
    }

    const previousReports = reports
    setReports((currentReports) =>
      currentReports.map((report) =>
        report.id === reportId ? { ...report, status } : report,
      ),
    )
    setSelectedReportId(reportId)

    if (!session?.access_token) return

    try {
      if (status === 'accepted') {
        await apiRequest(`/admin/reports/${reportId}/accept`, session.access_token, {
          method: 'POST',
          body: JSON.stringify({ note: 'Laporan diverifikasi admin.' }),
        })
      } else if (status === 'rejected') {
        await apiRequest(`/admin/reports/${reportId}/reject`, session.access_token, {
          method: 'POST',
          body: JSON.stringify({ note: 'Laporan ditolak admin.' }),
        })
      } else {
        await apiRequest(`/admin/reports/${reportId}/status`, session.access_token, {
          method: 'PATCH',
          body: JSON.stringify({ status }),
        })
      }

      await loadAdminData(session.access_token)
    } catch (error) {
      setReports(previousReports)
      setDataError(error.message)
    }
  }

  const submitResolveProof = async (event) => {
    event.preventDefault()
    if (!resolveDraft || !session?.access_token) return

    if (!resolveProofFile) {
      setResolveError('Foto bukti penyelesaian wajib diunggah.')
      return
    }

    setIsResolving(true)
    setResolveError('')

    try {
      const extension = resolveProofFile.name.split('.').pop() || 'jpg'
      const filePath = `resolution-proofs/${resolveDraft.id}-${crypto.randomUUID()}.${extension}`

      const { error } = await supabase.storage
        .from('report-photos')
        .upload(filePath, resolveProofFile, {
          cacheControl: '3600',
          upsert: false,
        })

      if (error) throw error

      const { data } = supabase.storage
        .from('report-photos')
        .getPublicUrl(filePath)

      await apiRequest(
        `/admin/reports/${resolveDraft.id}/resolve`,
        session.access_token,
        {
          method: 'POST',
          body: JSON.stringify({
            proofPhotoUrl: data.publicUrl,
            note: resolveNote,
          }),
        },
      )

      setResolveDraft(null)
      setResolveProofFile(null)
      setResolveNote('')
      await loadAdminData(session.access_token)
    } catch (error) {
      setResolveError(error.message || 'Gagal menyelesaikan laporan.')
    } finally {
      setIsResolving(false)
    }
  }

  const showDetail = (reportId) => {
    setSelectedReportId(reportId)
    setActiveMenu('Detail Laporan')
    window.requestAnimationFrame(() => {
      document.getElementById('detail-laporan')?.scrollIntoView({
        behavior: 'smooth',
        block: 'start',
      })
    })
  }

  const handleMapSearchSubmit = async (event) => {
    event.preventDefault()
    const query = mapSearch.trim()
    if (!query) return

    setIsMapSearching(true)
    setMapSearchError('')

    try {
      const results = await searchMapLocations(query)
      setMapSearchResults(results)

      if (results.length > 0) {
        setSelectedReportId('')
        setMapSearchCenter(results[0])
      } else {
        setMapSearchError('Lokasi tidak ditemukan di Indonesia.')
      }
    } catch {
      setMapSearchError('Gagal mencari lokasi.')
    } finally {
      setIsMapSearching(false)
    }
  }

  const selectMapSearchResult = (result) => {
    setSelectedReportId('')
    setMapSearchCenter(result)
    setMapSearch(result.label)
    setMapSearchResults([])
  }

  useEffect(() => {
    const query = mapSearch.trim()
    if (query.length < 3) {
      const timeoutId = window.setTimeout(() => {
        setMapSearchResults([])
        setMapSearchError('')
      }, 0)

      return () => window.clearTimeout(timeoutId)
    }

    let isCancelled = false
    const timeoutId = window.setTimeout(async () => {
      setIsMapSearching(true)
      setMapSearchError('')

      try {
        const results = await searchMapLocations(query)
        if (isCancelled) return

        setMapSearchResults(results)
        if (results.length === 0) {
          setMapSearchError('Lokasi tidak ditemukan di Indonesia.')
        }
      } catch {
        if (!isCancelled) {
          setMapSearchError('Gagal mencari lokasi.')
        }
      } finally {
        if (!isCancelled) {
          setIsMapSearching(false)
        }
      }
    }, 500)

    return () => {
      isCancelled = true
      window.clearTimeout(timeoutId)
    }
  }, [mapSearch])

  const resetFilters = () => {
    setActiveFilter('all')
    setSearch('')
    setDateFilter({ start: '', end: '' })
    setActiveMenu('Dashboard')
  }

  const handleLogin = async (event) => {
    event.preventDefault()
    setIsLoginLoading(true)
    setLoginError('')

    try {
      const { data, error } = await supabase.auth.signInWithPassword({
        email: loginForm.email,
        password: loginForm.password,
      })

      if (error) throw error

      setSession(data.session)
      setAdminUser(data.user)
      setIsLoggedIn(true)
      setLoginForm({ email: '', password: '' })
    } catch (error) {
      setLoginError(error.message || 'Login gagal.')
    } finally {
      setIsLoginLoading(false)
    }
  }

  const handleLogout = async () => {
    await supabase.auth.signOut()
    setSession(null)
    setAdminUser(null)
    setIsLoggedIn(false)
    resetFilters()
    setSelectedReportId('')
    setReports([])
    setDashboardStats(null)
    setDataError('')
  }

  const contentMode =
    activeMenu === 'Dashboard'
      ? 'dashboard'
      : activeMenu === 'Data Laporan' || activeMenu === 'Kategori Laporan'
        ? 'reports'
        : activeMenu === 'Peta Laporan'
          ? 'map'
          : activeMenu === 'Statistik'
            ? 'statistics'
            : activeMenu === 'Pengaturan' || activeMenu === 'Data Admin'
              ? 'settings'
              : activeMenu === 'Detail Laporan'
                ? 'detail'
                : 'dashboard'

  if (!isLoggedIn) {
    return (
      <main className="login-page">
        <section className="login-card">
          <div className="login-brand">
            <div className="brand-mark">LI</div>
            <div>
              <strong>Lapor Infrastruktur</strong>
              <span>Admin Kota</span>
            </div>
          </div>

          <div className="login-copy">
            <p>Masuk sebagai admin untuk mengelola laporan warga.</p>
            <h1>Dashboard Admin</h1>
          </div>

          <form className="login-form" onSubmit={handleLogin}>
            <label>
              <span>Email</span>
              <input
                autoComplete="email"
                onChange={(event) =>
                  setLoginForm((current) => ({
                    ...current,
                    email: event.target.value,
                  }))
                }
                placeholder="admin@domain.com"
                type="email"
                value={loginForm.email}
              />
            </label>
            <label>
              <span>Password</span>
              <input
                autoComplete="current-password"
                onChange={(event) =>
                  setLoginForm((current) => ({
                    ...current,
                    password: event.target.value,
                  }))
                }
                placeholder="admin"
                type="password"
                value={loginForm.password}
              />
            </label>
            {loginError ? <p className="login-error">{loginError}</p> : null}
            <button disabled={isLoginLoading} type="submit">
              {isLoginLoading ? 'Masuk...' : 'Login'}
            </button>
          </form>
        </section>
      </main>
    )
  }

  return (
    <main className="admin-shell">
      <aside className="sidebar">
        <div className="sidebar-brand">
          <div className="brand-mark">LI</div>
          <div>
            <strong>Lapor Infrastruktur</strong>
            <span>Admin Kota</span>
          </div>
        </div>

        <div className="balance-card">
          <span>Total Laporan</span>
          <strong>{reports.length}</strong>
        </div>

        <nav className="side-menu" aria-label="Menu admin">
          {menuItems.map(([icon, label]) => (
            <div className="menu-group" key={label}>
              <button
                className={activeMenu === label ? 'active' : ''}
                onClick={() => {
                  if (label === 'Dashboard') {
                    resetFilters()
                    return
                  }

                  if (label === 'Kategori Laporan') {
                    setIsCategoryOpen((current) => !current)
                    setActiveMenu(label)
                    return
                  }

                  if (label === 'Peta Laporan') {
                    openPanel('peta-laporan', label)
                    return
                  }

                  if (label === 'Statistik') {
                    openPanel('statistik-laporan', label)
                    return
                  }

                  if (label === 'Pengaturan') {
                    openPanel('pengaturan-admin', label)
                    return
                  }

                  openReportList('all', label)
                }}
                type="button"
              >
                <span>{icon}</span>
                {label}
                {label === 'Kategori Laporan' ? (
                  <b>{isCategoryOpen ? '-' : '+'}</b>
                ) : null}
              </button>

              {label === 'Kategori Laporan' && isCategoryOpen ? (
                <div className="submenu">
                  {categoryMenuItems.map(([subIcon, subLabel]) => (
                    <button
                      className={activeFilter === subLabel ? 'active' : ''}
                      key={subLabel}
                      onClick={() => openReportList(subLabel, 'Kategori Laporan')}
                      type="button"
                    >
                      <span>{subIcon}</span>
                      {subLabel}
                    </button>
                  ))}
                </div>
              ) : null}
            </div>
          ))}
        </nav>
      </aside>

      <section className="workspace">
        <header className="topbar">
          <button className="menu-toggle" type="button" aria-label="Buka menu">
            =
          </button>
          <div>
            <p>Dashboard Admin</p>
            <h1>Lapor Infrastruktur</h1>
          </div>
          <div className="topbar-actions">
            <span className="notif">12</span>
            <span className="admin-avatar">
              {(adminUser?.email?.[0] || 'A').toUpperCase()}
            </span>
            <select defaultValue="admin">
              <option value="admin">Kepala Admin</option>
              <option value="operator">Operator</option>
            </select>
            <button className="logout-button" onClick={handleLogout} type="button">
              Logout
            </button>
          </div>
        </header>

        <div className={`content content-${contentMode}`}>
          {dataError ? (
            <div className="empty-state">{dataError}</div>
          ) : null}
          {isLoadingData ? (
            <div className="empty-state">Mengambil data backend...</div>
          ) : null}
          <section className="panel dashboard-filter-panel">
            <div>
              <h2>Filter Dashboard</h2>
              <span>
                {dateFilteredReports.length} dari {reports.length} laporan
              </span>
            </div>
            <label>
              <span>Dari tanggal</span>
              <input
                type="date"
                value={dateFilter.start}
                onChange={(event) =>
                  setDateFilter((current) => ({
                    ...current,
                    start: event.target.value,
                  }))
                }
              />
            </label>
            <label>
              <span>Sampai tanggal</span>
              <input
                type="date"
                value={dateFilter.end}
                onChange={(event) =>
                  setDateFilter((current) => ({
                    ...current,
                    end: event.target.value,
                  }))
                }
              />
            </label>
            <button
              onClick={() => setDateFilter({ start: '', end: '' })}
              type="button"
            >
              Reset
            </button>
          </section>
          <section className="stats-grid" aria-label="Ringkasan dashboard">
            {stats.map((stat) => (
              <button
                className={`stat-card ${stat.tone} ${
                  activeFilter === stat.filter ? 'active' : ''
                }`}
                key={stat.label}
                onClick={() => openReportList(stat.filter)}
                type="button"
              >
                <span>{stat.label}</span>
                <strong>{stat.value}</strong>
                <small>Lihat semua</small>
              </button>
            ))}
          </section>

          <section className="dashboard-grid" id="statistik-laporan">
            <DonutChart
              title="Kategori Laporan"
              total={dateFilteredReports.length.toString()}
              segments={categoryChart}
            />
            <DonutChart
              title="Tingkat Kerusakan"
              total={dateFilteredReports.length.toString()}
              segments={levelChart}
            />
          </section>

          <section className="panel settings-panel" id="pengaturan-admin">
            <header className="panel-heading">
              <h2>Pengaturan Admin</h2>
              <span>Akses dan fitur utama</span>
            </header>
            <div className="settings-grid">
              {adminSettings.map((setting) => (
                <label className="setting-item" key={setting}>
                  <input defaultChecked type="checkbox" />
                  <span>{setting}</span>
                </label>
              ))}
            </div>
          </section>

          <section className="lower-grid">
            <article className="panel reports-panel" id="data-laporan">
              <header className="panel-heading">
                <h2>Data Laporan</h2>
                <span>
                  {filteredReports.length} dari {dateFilteredReports.length} laporan
                </span>
              </header>
              <div className="report-tools">
                <label>
                  <span>Cari laporan</span>
                  <input
                    value={search}
                    onChange={(event) => setSearch(event.target.value)}
                    placeholder="Cari ID, lokasi, kategori, status"
                    type="search"
                  />
                </label>
                <select
                  value={activeFilter}
                  onChange={(event) =>
                    openReportList(event.target.value, 'Data Laporan')
                  }
                >
                  <option value="all">Semua laporan</option>
                  <option value="pending">Menunggu</option>
                  <option value="queued">Antrean</option>
                  <option value="accepted">Diterima</option>
                  <option value="in_progress">Diproses</option>
                  <option value="resolved">Selesai</option>
                  <option value="rejected">Ditolak</option>
                  <option value="suspected_spam">Dugaan Spam</option>
                  <option value="High">Prioritas High</option>
                  <option value="Mid">Prioritas Mid</option>
                  <option value="Low">Prioritas Low</option>
                  {categoryNames.map((category) => (
                    <option key={category} value={category}>
                      {category}
                    </option>
                  ))}
                </select>
                <select
                  aria-label="Urutkan tanggal"
                  value={sortDate}
                  onChange={(event) => setSortDate(event.target.value)}
                >
                  <option value="newest">Tanggal terbaru</option>
                  <option value="oldest">Tanggal terlama</option>
                </select>
              </div>
              <div className="table-wrap">
                <table>
                  <thead>
                    <tr>
                      <th>ID</th>
                      <th>Lokasi</th>
                      <th>Kategori</th>
                      <th>Tanggal</th>
                      <th>Tingkat</th>
                      <th>Status</th>
                      <th>Aksi</th>
                    </tr>
                  </thead>
                  <tbody>
                    {filteredReports.map((report, index) => {
                      const displayId =
                        sortDate === 'oldest'
                          ? index + 1
                          : filteredReports.length - index

                      return (
                      <tr key={report.id}>
                        <td>#{String(displayId).padStart(3, '0')}</td>
                        <td>{report.locationName || 'Mencari nama lokasi...'}</td>
                        <td>{report.category}</td>
                        <td>{report.date}</td>
                        <td>
                          <span className={`level-badge ${report.level.toLowerCase()}`}>
                            {report.level}
                          </span>
                        </td>
                        <td>
                          <span className={`status-badge ${statusClassName(report.status)}`}>
                            {statusLabel(report.status)}
                          </span>
                        </td>
                        <td>
                          <div className="actions">
                            <button
                              onClick={() => showDetail(report.id)}
                              type="button"
                            >
                              Detail
                            </button>
                            <select
                              aria-label={`Ubah status laporan ${report.id}`}
                              onChange={(event) =>
                                updateStatus(report.id, event.target.value)
                              }
                              value={report.status}
                            >
                              {statusOptions.map(([value, label]) => (
                                <option key={value} value={value}>
                                  {label}
                                </option>
                              ))}
                            </select>
                          </div>
                        </td>
                      </tr>
                      )
                    })}
                  </tbody>
                </table>
              </div>
              {filteredReports.length === 0 ? (
                <div className="empty-state">
                  Tidak ada laporan yang cocok dengan pencarian.
                </div>
              ) : null}
            </article>

            <article className="panel monthly-panel">
              <header className="panel-heading">
                <h2>Grafik Bulanan</h2>
                <span>2026</span>
              </header>
              <div className="bar-list">
                {monthlyReports.map(([month, value]) => (
                  <div className="bar-row" key={month}>
                    <span>{month}</span>
                    <div>
                      <i style={{ width: `${(value / 180) * 100}%` }} />
                    </div>
                    <strong>{value}</strong>
                  </div>
                ))}
              </div>
            </article>
          </section>

          <section className="info-grid">
            <article className="panel category-panel">
              <header className="panel-heading">
                <h2>Kategori Kerusakan</h2>
                <span>7 kategori</span>
              </header>
              <div className="category-grid">
                {categories.map(([title, ...items]) => (
                  <div className="category-card" key={title}>
                    <h3>{title}</h3>
                    {items.map((item) => (
                      <span key={item}>{item}</span>
                    ))}
                  </div>
                ))}
              </div>
            </article>

            <article className="panel priority-panel">
              <header className="panel-heading">
                <h2>Tingkat Kerusakan</h2>
                <span>SLA penanganan</span>
              </header>
              <div className="priority-list">
                {priorities.map((priority) => (
                  <div className={`priority-card ${priority.tone}`} key={priority.level}>
                    <h3>{priority.level}</h3>
                    <p>{priority.condition}</p>
                    <span>{priority.example}</span>
                    <strong>Target {priority.target}</strong>
                  </div>
                ))}
              </div>
            </article>
          </section>

          <section className="detail-grid">
            <article className="panel detail-panel" id="detail-laporan">
              <header className="panel-heading">
                <h2>Detail Laporan</h2>
                <span>{selectedReport ? `#${selectedReport.id}` : 'Belum ada laporan'}</span>
              </header>
              {selectedReport ? (
                <>
                  <div className="detail-content">
                    <div className="damage-photo">
                      {selectedReport.photoUrl ? (
                        <img alt="Foto kerusakan" src={selectedReport.photoUrl} />
                      ) : (
                        <span>Foto Kerusakan</span>
                      )}
                    </div>
                    <dl>
                      <div>
                        <dt>ID Laporan</dt>
                        <dd>#{selectedReport.id}</dd>
                      </div>
                      <div>
                        <dt>Pelapor</dt>
                        <dd>{selectedReport.reporterName}</dd>
                      </div>
                      <div>
                        <dt>Kategori</dt>
                        <dd>{selectedReport.category}</dd>
                      </div>
                      <div>
                        <dt>Lokasi</dt>
                        <dd>
                          {selectedReport.locationName || selectedReport.location}
                        </dd>
                      </div>
                      <div>
                        <dt>Tanggal</dt>
                        <dd>{selectedReport.date}</dd>
                      </div>
                      <div>
                        <dt>Tingkat</dt>
                        <dd>
                          <span
                            className={`level-badge ${selectedReport.level.toLowerCase()}`}
                          >
                            {selectedReport.level}
                          </span>
                        </dd>
                      </div>
                      <div>
                        <dt>Status</dt>
                        <dd>
                          <span
                            className={`status-badge ${statusClassName(
                              selectedReport.status,
                            )}`}
                          >
                            {statusLabel(selectedReport.status)}
                          </span>
                        </dd>
                      </div>
                      <div>
                        <dt>Interaksi</dt>
                        <dd>
                          {selectedReport.upvoteCount} upvote,{' '}
                          {selectedReport.commentCount} komentar,{' '}
                          {selectedReport.flagCount} report
                        </dd>
                      </div>
                      <div className="full">
                        <dt>Deskripsi</dt>
                        <dd>{selectedReport.description}</dd>
                      </div>
                      {selectedReport.status === 'resolved' &&
                      selectedReport.resolutionProofPhotoUrl ? (
                        <div className="full resolution-proof-box">
                          <dt>Bukti Penyelesaian</dt>
                          <dd>
                            <img
                              alt="Bukti penyelesaian laporan"
                              src={selectedReport.resolutionProofPhotoUrl}
                            />
                            {selectedReport.resolutionNote ? (
                              <span>{selectedReport.resolutionNote}</span>
                            ) : null}
                          </dd>
                        </div>
                      ) : null}
                      <div className="full description-box">
                        <dt>Catatan Admin</dt>
                        <dd>
                          Periksa foto, lokasi, dan riwayat laporan sebelum memutuskan
                          apakah laporan diproses, diselesaikan, atau ditolak.
                        </dd>
                      </div>
                    </dl>
                  </div>
                  <div className="detail-actions">
                    <label>
                      <span>Ubah status</span>
                      <select
                        onChange={(event) =>
                          updateStatus(selectedReport.id, event.target.value)
                        }
                        value={selectedReport.status}
                      >
                        {statusOptions.map(([value, label]) => (
                          <option key={value} value={value}>
                            {label}
                          </option>
                        ))}
                      </select>
                    </label>
                  </div>
                </>
              ) : (
                <div className="empty-state">
                  Belum ada laporan dari backend untuk ditampilkan.
                </div>
              )}
            </article>

            <article className="panel map-panel" id="peta-laporan">
              <header className="panel-heading">
                <h2>Peta Laporan</h2>
                <span>
                  {activeMapReport?.locationName ||
                    mapSearchCenter?.label ||
                    activeMapReport?.location ||
                    'Belum ada laporan'}
                </span>
              </header>
              <form className="map-search" onSubmit={handleMapSearchSubmit}>
                <label>
                  <span>Cari lokasi</span>
                  <input
                    onChange={(event) => setMapSearch(event.target.value)}
                    placeholder="Cari jalan, gedung, atau area"
                    type="search"
                    value={mapSearch}
                  />
                </label>
                <button disabled={isMapSearching} type="submit">
                  {isMapSearching ? 'Mencari...' : 'Cari'}
                </button>
              </form>
              {mapSearchError ? (
                <div className="map-search-error">{mapSearchError}</div>
              ) : null}
              {mapSearchResults.length > 0 ? (
                <div className="map-search-results">
                  {mapSearchResults.map((result) => (
                    <button
                      key={result.id}
                      onClick={() => selectMapSearchResult(result)}
                      type="button"
                    >
                      {result.label}
                    </button>
                  ))}
                </div>
              ) : null}
              <AdminReportMap
                onSelectReport={showDetail}
                reports={reports}
                searchCenter={mapSearchCenter}
                selectedReport={activeMapReport}
              />
              <div className="map-meta">
                <strong>Lokasi dipilih</strong>
                <span>
                  {activeMapReport?.mapQuery ||
                    (mapSearchCenter
                      ? coordinateLabel(
                        mapSearchCenter.latitude,
                        mapSearchCenter.longitude,
                      )
                      : 'Belum ada laporan')}
                </span>
                <em>Peta memakai OpenStreetMap gratis seperti aplikasi warga.</em>
                <a href={mapSearchUrl} rel="noreferrer" target="_blank">
                  Buka di Google Maps
                </a>
              </div>
            </article>
          </section>
        </div>
      </section>
      {resolveDraft ? (
        <div className="modal-backdrop" role="presentation">
          <form className="resolve-modal" onSubmit={submitResolveProof}>
            <header>
              <div>
                <h2>Bukti Penyelesaian</h2>
                <span>{resolveDraft.category}</span>
              </div>
              <button
                onClick={() => setResolveDraft(null)}
                type="button"
                aria-label="Tutup"
              >
                x
              </button>
            </header>
            <p>
              Untuk mengubah status menjadi Selesai, admin wajib mengunggah foto
              bukti penanganan.
            </p>
            <label>
              <span>Foto bukti</span>
              <input
                accept="image/*"
                onChange={(event) =>
                  setResolveProofFile(event.target.files?.[0] ?? null)
                }
                type="file"
              />
            </label>
            <label>
              <span>Catatan</span>
              <textarea
                onChange={(event) => setResolveNote(event.target.value)}
                placeholder="Contoh: Jalan sudah ditambal dan aman dilalui."
                rows="3"
                value={resolveNote}
              />
            </label>
            {resolveError ? (
              <div className="resolve-error">{resolveError}</div>
            ) : null}
            <div className="resolve-actions">
              <button
                onClick={() => setResolveDraft(null)}
                type="button"
                disabled={isResolving}
              >
                Batal
              </button>
              <button disabled={isResolving} type="submit">
                {isResolving ? 'Mengirim...' : 'Tandai Selesai'}
              </button>
            </div>
          </form>
        </div>
      ) : null}
    </main>
  )
}

export default App
