{% set config = salt['omv_conf.get']('conf.system.backup') %}

# Default variable
{% set OMV_BACKUP_DIR_NAME = salt['pillar.get']('default:OMV_BACKUP_DIR_NAME', 'omvbackup') %}
{% set OMV_BACKUP_FILE_PREFIX = salt['pillar.get']('default:OMV_BACKUP_FILE_PREFIX', 'backup-omv') %}
{% set OMV_BACKUP_MAX_DEPTH = salt['pillar.get']('default:OMV_BACKUP_MAX_DEPTH', 'omvbackup') %}
