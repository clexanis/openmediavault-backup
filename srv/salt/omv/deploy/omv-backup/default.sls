{% set config = salt['omv_conf.get']('conf.system.backup') %}

# Default variable
{% set OMV_BACKUP_DIR_NAME = salt['pillar.get']('default:OMV_BACKUP_DIR_NAME', 'omvbackup') %}
{% set OMV_BACKUP_FILE_PREFIX = salt['pillar.get']('default:OMV_BACKUP_FILE_PREFIX', 'backup-omv') %}
{% set OMV_BACKUP_MAX_DEPTH = salt['pillar.get']('default:OMV_BACKUP_MAX_DEPTH', '1') %}
{% set OMV_BACKUP_ZSTD_OPTIONS = salt['pillar.get']('default:OMV_BACKUP_ZSTD_OPTIONS', '-T0 --long') %}
{% set OMV_BACKUP_ZSTD_ADAPT = salt['pillar.get']('default:OMV_BACKUP_ZSTD_ADAPT', '') %}
{% set OMV_BACKUP_FSA_COMP_LEVEL = salt['pillar.get']('default:OMV_BACKUP_FSA_COMP_LEVEL', '2') %}
