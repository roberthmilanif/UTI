import React, { useContext } from 'react';
import { useNavigate } from 'react-router-dom';
import { PatientContext } from '../../contexts/PatientContext';
import './PatientList.css';

function PatientList() {
  const { patients, selectPatient, selectedPatient } = useContext(PatientContext);
  const navigate = useNavigate();

  const handleEdit = (patientId) => {
    selectPatient(patientId); // Ensure the correct patient is selected in context
    navigate('/edit-patient');
  };

  const handleSelect = (patientId) => {
    selectPatient(patientId);
    // No navigation here, PatientView will pick up the change from context
  };

  if (!patients || patients.length === 0) {
    return (
      <div className="patient-list-container">
        <h2>Lista de Pacientes</h2> {/* Patient List */}
        <p>Nenhum paciente disponível. Clique em "Adicionar Novo Paciente" para criar um.</p> {/* No patients available... */}
      </div>
    );
  }

  return (
    <div className="patient-list-container">
      <h2>Lista de Pacientes</h2> {/* Patient List */}
      <ul className="patient-list">
        {patients.map(patient => (
          <li
            key={patient.id}
            className={`patient-list-item ${selectedPatient && selectedPatient.id === patient.id ? 'selected' : ''}`}
          >
            <div className="patient-info" onClick={() => handleSelect(patient.id)}>
              {patient.name}
            </div>
            <button
              className="edit-button"
              onClick={(e) => {
                e.stopPropagation(); // Prevent li's onClick if button is clicked
                handleEdit(patient.id);
              }}
            >
              Editar {/* Edit */}
            </button>
          </li>
        ))}
      </ul>
    </div>
  );
}

export default PatientList;
